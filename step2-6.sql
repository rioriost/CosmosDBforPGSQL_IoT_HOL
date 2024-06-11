CREATE TABLE sensors(
    sensor_id bigint NOT NULL,
    sensor_name varchar(16) NOT NULL,
    sensed_time timestamptz NOT NULL,
    ingest_time timestamptz NOT NULL,
    sec_00 numeric(10,4),
    sec_01 numeric(10,4),
    sec_02 numeric(10,4),
    sec_03 numeric(10,4),
    sec_04 numeric(10,4),
    sec_05 numeric(10,4),
    sec_06 numeric(10,4),
    sec_07 numeric(10,4),
    sec_08 numeric(10,4),
    sec_09 numeric(10,4),
    sec_10 numeric(10,4),
    sec_11 numeric(10,4),
    sec_12 numeric(10,4),
    sec_13 numeric(10,4),
    sec_14 numeric(10,4),
    sec_15 numeric(10,4),
    sec_16 numeric(10,4),
    sec_17 numeric(10,4),
    sec_18 numeric(10,4),
    sec_19 numeric(10,4),
    sec_20 numeric(10,4),
    sec_21 numeric(10,4),
    sec_22 numeric(10,4),
    sec_23 numeric(10,4),
    sec_24 numeric(10,4),
    sec_25 numeric(10,4),
    sec_26 numeric(10,4),
    sec_27 numeric(10,4),
    sec_28 numeric(10,4),
    sec_29 numeric(10,4),
    sec_30 numeric(10,4),
    sec_31 numeric(10,4),
    sec_32 numeric(10,4),
    sec_33 numeric(10,4),
    sec_34 numeric(10,4),
    sec_35 numeric(10,4),
    sec_36 numeric(10,4),
    sec_37 numeric(10,4),
    sec_38 numeric(10,4),
    sec_39 numeric(10,4),
    sec_40 numeric(10,4),
    sec_41 numeric(10,4),
    sec_42 numeric(10,4),
    sec_43 numeric(10,4),
    sec_44 numeric(10,4),
    sec_45 numeric(10,4),
    sec_46 numeric(10,4),
    sec_47 numeric(10,4),
    sec_48 numeric(10,4),
    sec_49 numeric(10,4),
    sec_50 numeric(10,4),
    sec_51 numeric(10,4),
    sec_52 numeric(10,4),
    sec_53 numeric(10,4),
    sec_54 numeric(10,4),
    sec_55 numeric(10,4),
    sec_56 numeric(10,4),
    sec_57 numeric(10,4),
    sec_58 numeric(10,4),
    sec_59 numeric(10,4)
) PARTITION BY RANGE (sensed_time);

CREATE INDEX sensor_name_index ON sensors (sensor_name);

SELECT create_distributed_table('sensors', 'sensor_id');

SELECT create_time_partitions(
    table_name         := 'sensors',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);

SELECT cron.schedule('create-partitions_sensors',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);

SELECT cron.schedule('compress-partitions_sensors',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors',
        now() - interval '5 days', 'columnar') $$
);

CREATE TABLE sensors_1min(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4)
    CHECK (sensed_time = date_trunc('minute', sensed_time))
) PARTITION BY RANGE (sensed_time);

CREATE INDEX sensor_name_1min_index ON sensors_1min (sensor_name);

SELECT create_distributed_table('sensors_1min', 'sensor_id');

SELECT create_time_partitions(
    table_name         := 'sensors_1min',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);

SELECT cron.schedule('create-partitions_sensors_1min',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1min',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);

SELECT cron.schedule('compress-partitions_sensors_1min',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1min',
        now() - interval '5 days', 'columnar') $$
);

CREATE TABLE latest_rollup_1min (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('minute', rolled_at))
);

CREATE TABLE sensors_1hour(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('hour', sensed_time))
) PARTITION BY RANGE (sensed_time);

CREATE INDEX sensor_name_1hour_index ON sensors_1hour (sensor_name);

SELECT create_distributed_table('sensors_1hour', 'sensor_id');

SELECT create_time_partitions(
    table_name         := 'sensors_1hour',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);

SELECT cron.schedule('create-partitions_sensors_1hour',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1hour',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);

SELECT cron.schedule('compress-partitions_sensors_1hour',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1hour',
        now() - interval '5 days', 'columnar') $$
);

CREATE TABLE latest_rollup_1hour (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('hour', rolled_at))
);

CREATE TABLE sensors_1day(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('day', sensed_time))
) PARTITION BY RANGE (sensed_time);

CREATE INDEX sensor_name_1day_index ON sensors_1day (sensor_name);

SELECT create_distributed_table('sensors_1day', 'sensor_id');

SELECT create_time_partitions(
    table_name         := 'sensors_1day',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);

SELECT cron.schedule('create-partitions_sensors_1day',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1day',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);

SELECT cron.schedule('compress-partitions_sensors_1day',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1day',
        now() - interval '5 days', 'columnar') $$
);

CREATE TABLE latest_rollup_1day (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);

CREATE TABLE sensors_1week(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('day', sensed_time))
) PARTITION BY RANGE (sensed_time);

CREATE INDEX sensor_name_1week_index ON sensors_1week (sensor_name);

SELECT create_distributed_table('sensors_1week', 'sensor_id');

SELECT create_time_partitions(
    table_name         := 'sensors_1week',
    partition_interval := '1 week',
    end_at             := now() + '2 weeks'
);

SELECT cron.schedule('create-partitions_sensors_1week',
    '@weekly',
    $$SELECT create_time_partitions(table_name:='sensors_1week',
        partition_interval:= '1 week',
        end_at:= now() + '2 weeks') $$
);

SELECT cron.schedule('compress-partitions_sensors_1week',
    '@weekly',
    $$CALL alter_old_partitions_set_access_method('sensors_1week',
        now() - interval '5 weeks', 'columnar') $$
);

CREATE TABLE latest_rollup_1week (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);
