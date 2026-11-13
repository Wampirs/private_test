FROM postgres:18.7 AS replica
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-18-partman \
 && rm -rf /var/lib/apt/lists/*

FROM replica AS main
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-18-cron \
 && rm -rf /var/lib/apt/lists/*