# Тестове завдання: PostgreSQL

Реалізація завдання з [Task.md](Task.md): партиціонована таблиця `t1`, генерація даних, регламентні завдання, матеріалізоване представлення з підсумками та логічна реплікація на другий інстанс.

Усе піднімається через Docker Compose: два контейнери PostgreSQL 18, основний і репліка. Схема, процедури, завдання та реплікація налаштовуються автоматично при першому старті.

## Запуск

Потрібні Docker і Docker Compose.

```bash
docker compose up -d --build
```

Репліка стартує після того, як основна база завершить ініціалізацію, тож перший запуск триває близько хвилини.

| Інстанс | Контейнер | Порт на хості | База | Користувач / пароль |
|---|---|---|---|---|
| Основний | `pg_main_container` | 5430 | `priv_main_db` | `pos_us` / `pos_pass` |
| Репліка | `pg_replica_container` | 5431 | `priv_replica_db` | `pos_us` / `pos_pass` |

### Генерація даних

Історичні дані не генеруються автоматично. Після старту викличте процедуру на основній базі:

```bash
docker exec -it pg_main_container psql -U pos_us -d priv_main_db \
  -c "CALL generate_t1_data(now() - interval '4 months', now(), 100000);"
```

Параметри: початок періоду, кінець періоду, кількість рядків і необов'язковий розмір батча (за замовчуванням 10 000).

### Повне перестворення

Init-скрипти виконуються лише на порожньому каталозі даних, а підписка репліки прив'язана до слота на основній базі. Тому обидві бази треба перестворювати разом:

```bash
docker compose down
rm -rf pgdata_main pgdata_replica
docker compose up -d --build
```

## Структура

```
Dockerfile              образи: replica (pg_partman), main (pg_partman + pg_cron)
docker-compose.yml      два сервіси, параметри сервера, облікові дані реплікації
sql/init.sh             застосовує sql/shared, потім скрипти свого інстансу
sql/shared/             виконується на обох інстансах: таблиця t1 і партиції
sql/main/               лише основний: індекс, унікальність, процедури, представлення, публікація, завдання
sql/replica/            лише репліка: підписка
```

## Як реалізовано кожен пункт

### 1. Партиціонована таблиця

[sql/shared/001_schema.sql](sql/shared/001_schema.sql), [sql/shared/002_partition.sql](sql/shared/002_partition.sql)

Таблиця `t1` партиціонована за діапазоном `t_date` по місяцях. Партиції створює `pg_partman`: від чотирьох місяців тому до чотирьох місяців наперед.

| Поле завдання | Колонка | Тип |
|---|---|---|
| айді | `id` | `bigint`, identity |
| дата | `t_date` | `timestamptz` |
| сума | `sum` | `numeric(18,2)` |
| стан | `state` | `smallint` |
| гуід операції | `op_guid` | `uuid` (UUIDv7) |
| повідомлення | `msg` | `jsonb` |

`msg` містить ключі `acc_num` (номер рахунку), `client_id` (айді клієнта) та `op_type` (тип операції, значення 1 або 2). Наявність ключів і допустимі значення `op_type` контролює обмеження `chk_t1_msg`.

### 2. Генерація даних

[sql/main/003_gen_procedure.sql](sql/main/003_gen_procedure.sql)

Процедура `generate_t1_data` вставляє рядки батчами з комітом після кожного. Дата рівномірно розподілена по заданому періоду, стан випадково 0 або 1, клієнти з діапазону 1–5000.

### 3. Унікальність гуїда операції

[sql/main/002_op_guid_register.sql](sql/main/002_op_guid_register.sql)

Унікальний індекс на партиціонованій таблиці мусить включати ключ партиціювання, тому гарантував би унікальність лише пари `(op_guid, t_date)`. Для наскрізної унікальності є окрема таблиця-реєстр `t1_op_guid_reg` з первинним ключем по `op_guid`: тригер `BEFORE INSERT` на `t1` записує туди кожен гуїд, і дублікат у будь-якій партиції завершується помилкою. (апдейт гуіда не передбачався і може пошкодити унікальність)

### 4. Додавання запису кожні 5 секунд

[sql/main/004_add_row_procedure.sql](sql/main/004_add_row_procedure.sql), [sql/main/010_cron_jobs.sql](sql/main/010_cron_jobs.sql)

Завдання `pg_cron` `task4_add_row` викликає `add_t1_row()`, яка вставляє один рядок зі `state = 0` і поточною датою.

### 5. Оновлення стану кожні 3 секунди

[sql/main/005_update_state_procedure.sql](sql/main/005_update_state_procedure.sql), [sql/main/001_schema_modify.sql](sql/main/001_schema_modify.sql)

Завдання `task5_update_state` викликає `update_t1_state()`. Процедура бере секунду поточного часу: якщо вона парна, переводить з 0 в 1 рядки з парним `id`, інакше з непарним. Частковий індекс `ix_t1_state_zero` по рядках зі `state = 0` дозволяє не сканувати всю таблицю.

### 6. Матеріалізоване представлення з підсумками

[sql/main/006_totals_matview.sql](sql/main/006_totals_matview.sql)

`mv_t1_totals` зберігає суму поля `sum` по `client_id` і `op_type` для рядків зі `state = 1`.

Оновлення запускає тригер рівня оператора на `UPDATE` таблиці `t1`. Через перехідні таблиці він перевіряє, чи хоч один рядок перейшов з 0 в 1, і лише тоді виконує `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Отже, представлення оновлюється один раз на оператор, а не на кожен рядок, і не блокує читання.

### 7. Реплікація

[sql/main/007_publication.sql](sql/main/007_publication.sql), [sql/replica/001_subscription.sql](sql/replica/001_subscription.sql)

Логічна реплікація таблиці `t1`. На основній базі створюються роль для реплікації та публікація `pub_t1`, на репліці — підписка `sub_t1`.

- Публікація має `publish_via_partition_root = true`: зміни передаються як зміни `t1`, і репліка сама розкладає їх по своїх партиціях.
- Логін і пароль ролі реплікації задані один раз у `docker-compose.yml` (блок `x-repl-env`) і передаються в SQL-скрипти як змінні `psql`.
- Дані, що з'явилися на основній базі до старту репліки, потрапляють на неї початковою копією при створенні підписки.

На репліку передається лише `t1`. Реєстр гуїдів, представлення й регламентні завдання існують тільки на основній базі.

## Перевірка

Підключення до основної бази:

```bash
docker exec -it pg_main_container psql -U pos_us -d priv_main_db
```

```sql
-- партиції та розподіл рядків
SELECT tableoid::regclass AS part, count(*) FROM t1 GROUP BY 1 ORDER BY 1;

-- регламентні завдання та їхні останні запуски
SELECT jobname, schedule, command, active FROM cron.job;
SELECT jobid, status, start_time FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- рядки, що чекають переходу в стан 1
SELECT id, t_date, state FROM t1 WHERE state = 0;

-- представлення збігається з прямим підрахунком
SELECT (SELECT sum(total_sum) FROM mv_t1_totals)   AS mv_sum,
       (SELECT sum(sum) FROM t1 WHERE state = 1)   AS t1_sum;

-- стан реплікації
SELECT slot_name, active FROM pg_replication_slots;
```

Порівняння з реплікою — той самий запит на обох інстансах:

```bash
Q="SELECT count(*), sum(sum) FROM t1 WHERE t_date < now() - interval '15 seconds'"
docker exec pg_main_container    psql -U pos_us -d priv_main_db    -c "$Q"
docker exec pg_replica_container psql -U pos_us -d priv_replica_db -c "$Q"
```

## Обмеження

- Унікальність гуїда перевіряється при вставці; оновлення `op_guid` наявного рядка тригер не контролює.
- Рядки, які `generate_t1_data` вставляє одразу зі станом 1, потрапляють у представлення при наступному переході будь-якого рядка з 0 в 1. Поки працюють регламентні завдання, це кілька секунд.
- Представлення перераховується повністю, тож час оновлення росте разом із таблицею (близько 0.1–0.2 с на 120 тис. рядків).
- Нові партиції після створених наперед автоматично не додаються: виклик `partman.run_maintenance()` не запланований, і рядки з пізнішими датами підуть у `t1_default`.
- Журнал запусків `cron.job_run_details` не очищується.
