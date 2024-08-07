# このハンズオンラボが想定するシナリオについて

工場や発電所、スマートビルディングなど、数万個あるセンサーが毎秒記録したデータを毎分、60秒間分をまとめて送出してくるシナリオを想定している。

センサーがグローバルに配置されている場合、Cosmos DB for PostgreSQL (CDBPG)はグローバル分散に対応しないため、Cosmos DB for NoSQLを用いてMulti-region Writeを実装すべきだが、Cosmos DB for NoSQLで受信後、ChangeFeedによりキックされたFunction等で特定のリージョン（例えばAzure東日本）に配置されたCDBPGに集約するシナリオは十分に考えられるし、実際にそのようなデザインのシステムは本番稼働している。

ハンズオンでは最小構成のクラスタをデプロイするが、センサーの数が増えた場合には以下の点に注意が必要。

サーバーパラメータのcitus.shard_countをデフォルトの32から、クラスタを構成するWorkerノードの総vCPU数と揃える。例えば、16vCPUのWorkerが4ノード存在するなら、citus.shard_countは64もしくは、それ以上の数値を設定する。citus.shard_countがデフォルトのままの場合、以下のようになる。

1. センサーが1,024個あり、このハンズオンのようにsensor_idをそのままシャードキーにする場合、生成されるシャードキーも1024通りに分散する。
2. citus.shard_countが32の場合にはシャードキーは32のレンジ（32bitハッシュの値の範囲を32分割する）となり、各レンジがWorkerノードに割り当てられるため、8シャード/ノードとなる。
3. 一方でvCPUは16であるから0.5シャード/vCPUとなり、1つのvCPUが2つのシャード＝プロセスを扱うことになる。プロセスの切り替えが発生するため、CPUのキャッシュヒット率が低くなる。citus.shard_countを64にすると、適切なサイズとなる。
4. Workerノードをスケールアウトする（4→8ノード）か、スケールアップする（16→32vCPU）かが考えられるが、データサイズが大きくIO負荷が高い場合はスケールアウトを選択しSSDの台数を増やし、そうで無い場合はスケールアップを選択するのが一般的な指針となる。
5. ノード数を増やす（クラスタスケールアウト）、SSDの容量を増やす（ストレージスケールアップ）、のいずれもトータルのIOPSも向上するが、いずれもスケールインが出来ない点にも注意。

# 0. Cosmos DB for PostgreSQL (CDBPG) について
CDBPGの基本的な操作については、ここでは触れない。

[ハンズオンラボ](https://github.com/tahayaka-microsoft/CosmosDBforPG_HoL/)を事前に受講しているか、独習済みであることが必須。

またこのハンズオンラボの内容は、上記リンクのハンズオンラボの「リアルタイムダッシュボード」の拡張版なので、基本的な事柄についての理解はそちらに譲る。

# 1. CDBPGのデプロイ
ハンズオンは、2 Workerノード(4vCPUs, 512GB)をデプロイし、デフォルトのサーバーパラメーターで実施する。4vCPUではAUTO_VACUUM時に性能のインパクトが大きいため、本番では8vCPU以上を設定すること。業務時間外にAUTO_VACUUMを実行できるのであればその限りではないものの、一般にIoTのシナリオではデータ到着のシーズナリティが低いため、8vCPU以上を推奨する。

最終的には以下のようなデータの分散・パーティショニングとなる。
![](layout.png)

# 2. RAWデータテーブル
## 2.1 テーブルの作成
sensor_nameをマスターに分離することも考えられる。ダミーデータではマスターを使って、複合ユニーク制約を模している。

sensor_idとsensor_nameは複合ユニーク制約のはずだが、ここでは実装しない。UNIQUE(sensor_id, sensor_name)

00〜59秒のデータがカラムに分離しているのは、columnar storageにおける圧縮率向上のため。array型でも同じようなデータが並ぶのであれば、array型で定義しても良い。その場合、後段のaggregationにおけるUNNEST処理などが変わるので注意。CREATE TABLE実行時にUSING COLUMNARキーワードを付加することで、HEAPをそもそも用いない構成も可能。圧縮による性能向上はかなり絶大なので、パフォーマンスベンチマークを実施してから決定しても良い。
```sql
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
```

## 2.1 インデックスの作成
```sql
CREATE INDEX sensor_name_index ON sensors (sensor_name);
```

## 2.2 シャードの設定
```sql
SELECT create_distributed_table('sensors', 'sensor_id');
```

以下のクエリでシャード設定が確認できる。
```sql
SELECT * FROM citus_shards;
```

## 2.3 パーティションの設定

毎時も可能だが、パーティション数が多くなりすぎる可能性があるため、総データ容量、データのボリューム、データライフサイクルを勘案して決定すべし。
```sql
SELECT create_time_partitions(
    table_name         := 'sensors',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

実行後に、\dで作成したテーブルを確認する。
```sql
\d
```

パーティションの管理については以下。
7日分のパーティションを作成
```sql
-- パーティションの削除
-- drop_old_time_partitions
-- heap / columnarの切り替え
-- alter_old_partitions_set_access_method
```

## 2.4 パーティション管理の自動化
7日分のパーティションの作成の自動化
```sql
SELECT cron.schedule('create-partitions_sensors',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

設定したcronジョブについてのクエリは以下。
```sql
-- ジョブの一覧
SELECT * FROM cron.job;
```
```sql
-- ジョブIDでジョブをスケジュールから削除
-- SELECT cron.unschedule(job id);
```

5日より古いパーティションの圧縮
```sql
SELECT cron.schedule('compress-partitions_sensors',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors',
        now() - interval '5 days', 'columnar') $$
);
```

# 3 毎分ロールアップ用テーブル
## 3.1 テーブルの作成
```sql
CREATE TABLE sensors_1min(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4)
    CHECK (sensed_time = date_trunc('minute', sensed_time))
) PARTITION BY RANGE (sensed_time);
```

## 3.2 インデックスの作成
```sql
CREATE INDEX sensor_name_1min_index ON sensors_1min (sensor_name);
```

## 3.3 シャードの設定
```sql
SELECT create_distributed_table('sensors_1min', 'sensor_id');
```

## 3.4 パーティションの設定
7日分のパーティションを作成
```sql
SELECT create_time_partitions(
    table_name         := 'sensors_1min',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 3.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```sql
SELECT cron.schedule('create-partitions_sensors_1min',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1min',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```sql
SELECT cron.schedule('compress-partitions_sensors_1min',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1min',
        now() - interval '5 days', 'columnar') $$
);
```

## 3.6 最後にロールアップした時間（分）の記録
テーブルの作成
```sql
CREATE TABLE latest_rollup_1min (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('minute', rolled_at))
);
```

# 4 毎時ロールアップ用テーブル
## 4.1 テーブルの作成
```sql
CREATE TABLE sensors_1hour(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('hour', sensed_time))
) PARTITION BY RANGE (sensed_time);
```

## 4.2 インデックスの作成
```sql
CREATE INDEX sensor_name_1hour_index ON sensors_1hour (sensor_name);
```

## 4.3 シャードの設定
```sql
SELECT create_distributed_table('sensors_1hour', 'sensor_id');
```

## 4.4 パーティションの設定
7日分のパーティションを作成
```sql
SELECT create_time_partitions(
    table_name         := 'sensors_1hour',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 4.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```sql
SELECT cron.schedule('create-partitions_sensors_1hour',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1hour',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```sql
SELECT cron.schedule('compress-partitions_sensors_1hour',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1hour',
        now() - interval '5 days', 'columnar') $$
);
```

## 4.6 最後にロールアップした時間（時）の記録
テーブルの作成
```sql
CREATE TABLE latest_rollup_1hour (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('hour', rolled_at))
);
```

# 5 日次ロールアップ用テーブル
## 5.1 テーブルの作成
```sql
CREATE TABLE sensors_1day(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('day', sensed_time))
) PARTITION BY RANGE (sensed_time);
```

## 5.2 インデックスの作成
```sql
CREATE INDEX sensor_name_1day_index ON sensors_1day (sensor_name);
```

## 5.3 シャードの設定
```sql
SELECT create_distributed_table('sensors_1day', 'sensor_id');
```

## 5.4 パーティションの設定
7日分のパーティションを作成
```sql
SELECT create_time_partitions(
    table_name         := 'sensors_1day',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 5.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```sql
SELECT cron.schedule('create-partitions_sensors_1day',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1day',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```sql
SELECT cron.schedule('compress-partitions_sensors_1day',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1day',
        now() - interval '5 days', 'columnar') $$
);
```

## 5.6 最後にロールアップした時間（日）の記録
テーブルの作成
```sql
CREATE TABLE latest_rollup_1day (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);
```

# 6 週次ロールアップ用テーブル
## 6.1 テーブルの作成
```sql
CREATE TABLE sensors_1week(
    sensor_id bigint,
    sensor_name varchar(16),
    sensed_time timestamptz,
    avg numeric(10,4),
    min numeric(10,4),
    max numeric(10,4),
    CHECK (sensed_time = date_trunc('day', sensed_time))
) PARTITION BY RANGE (sensed_time);
```

## 6.2 インデックスの作成
```sql
CREATE INDEX sensor_name_1week_index ON sensors_1week (sensor_name);
```

## 6.3 シャードの設定
```sql
SELECT create_distributed_table('sensors_1week', 'sensor_id');
```

## 6.4 パーティションの設定
2週分のパーティションを作成
```sql
SELECT create_time_partitions(
    table_name         := 'sensors_1week',
    partition_interval := '1 week',
    end_at             := now() + '2 weeks'
);
```

## 6.5 パーティション管理の自動化
2週分のパーティションの作成の自動化
```sql
SELECT cron.schedule('create-partitions_sensors_1week',
    '@weekly',
    $$SELECT create_time_partitions(table_name:='sensors_1week',
        partition_interval:= '1 week',
        end_at:= now() + '2 weeks') $$
);
```

5週より古いパーティションの圧縮
```sql
SELECT cron.schedule('compress-partitions_sensors_1week',
    '@weekly',
    $$CALL alter_old_partitions_set_access_method('sensors_1week',
        now() - interval '5 weeks', 'columnar') $$
);
```

## 6.6 最後にロールアップした時間（週）の記録
テーブルの作成
```sql
CREATE TABLE latest_rollup_1week (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);
```

# 7 ダミーデータ用センサーマスター
## 7.1 テーブルの作成
以下はここまでの設定で正しく動作するかを確認する手順。本番データはファイルなどでシステムに到着し、Storage TriggerなどでキックされたFunctions等がingestする。sensor_idやsensor_nameは元データの段階で一意性制約を満たしている想定だが、テーブル定義として制約を課しておくことに問題はない。

```sql
CREATE TABLE dummy_sensor_ms(
    sensor_id bigint,
    sensor_name varchar(16)
);
```

## 7.2 シャードの設定

マスターデータなので、Referenceテーブルとする。Referenceテーブルは、Distributedテーブルの亜種で、同一のシャードが全てのノードに置かれる。

```sql
SELECT create_reference_table('dummy_sensor_ms');
```

## 7.3 ダミーセンサーマスターのデータの生成

次のステップのセンサー数（generate_seriesの引数）と揃えること。

```sql
INSERT INTO dummy_sensor_ms (
    sensor_id, sensor_name
)
SELECT
    i,
    concat(('{SA,SB,SC,SD,SE,RA,RB,GF,GT,CL}'::text[])[ceil(random()*10)], '-', (random() * 1000000)::int % 10000)
FROM GENERATE_SERIES(1, 1024) AS i;
```
       
# 8 ダミーデータによるテスト
## 8.1 ダミーデータの生成
以下の内容のdummy_generator.sqlを作成し、psql -f dummy_generator.sqlで実行（バックグラウンド実行）する。クラウドシェルのエディタ、あるいはローカルマシン上に作成する方法のいずれも可能。

```sql
DO $$
BEGIN LOOP
    INSERT INTO sensors (
        sensor_id,
        sensor_name,
        sensed_time,
        ingest_time,
        sec_00, sec_01, sec_02, sec_03, sec_04, sec_05, sec_06, sec_07, sec_08, sec_09, sec_10, sec_11, sec_12, sec_13, sec_14, sec_15, sec_16, sec_17, sec_18, sec_19, sec_20, sec_21, sec_22, sec_23, sec_24, sec_25, sec_26, sec_27, sec_28, sec_29, sec_30, sec_31, sec_32, sec_33, sec_34, sec_35, sec_36, sec_37, sec_38, sec_39, sec_40, sec_41, sec_42, sec_43, sec_44, sec_45, sec_46, sec_47, sec_48, sec_49, sec_50, sec_51, sec_52, sec_53, sec_54, sec_55, sec_56, sec_57, sec_58, sec_59
    ) 
    SELECT
        i,
        ms.sensor_name,
        date_trunc('minute', now() - INTERVAL '1 minute'),
        clock_timestamp(),
        random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random()
    FROM GENERATE_SERIES(1, 1024) AS i
    JOIN dummy_sensor_ms ms ON ms.sensor_id = i
    ;
    COMMIT;
    PERFORM pg_sleep(60);
END LOOP;
END $$;
```

## 8.2 データ生成のチェック
```sql
SELECT * FROM sensors LIMIT 10;
```

# 9 毎分ロールアップ用関数
## 9.1 最終ロールアップ日時の初期化
```sql
INSERT INTO latest_rollup_1min VALUES ('10-10-1901');
```

## 9.2 関数の作成
```sql
CREATE OR REPLACE FUNCTION rollup_minutely() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('minute', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1min;
    BEGIN
        INSERT INTO sensors_1min (
            sensor_id, sensor_name, sensed_time,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('minute', sensed_time),
            AVG(vals), MIN(vals), MAX(vals) FROM (
                SELECT sensor_id, sensor_name, sensed_time, UNNEST(ARRAY[sec_00, sec_01, sec_02, sec_03, sec_04, sec_05, sec_06, sec_07, sec_08, sec_09, sec_10, sec_11, sec_12, sec_13, sec_14, sec_15, sec_16, sec_17, sec_18, sec_19, sec_20, sec_21, sec_22, sec_23, sec_24, sec_25, sec_26, sec_27, sec_28, sec_29, sec_30, sec_31, sec_32, sec_33, sec_34, sec_35, sec_36, sec_37, sec_38, sec_39, sec_40, sec_41, sec_42, sec_43, sec_44, sec_45, sec_46, sec_47, sec_48, sec_49, sec_50, sec_51, sec_52, sec_53, sec_54, sec_55, sec_56, sec_57, sec_58, sec_59]) AS vals
                FROM sensors
                WHERE date_trunc('minute', ingest_time) <@
                tstzrange(last_rollup_time, curr_rollup_time, '(]')
                ) AS unnested
                GROUP BY sensor_id, sensor_name, sensed_time;

        UPDATE latest_rollup_1min SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```
## 9.3 毎分ロールアップ用関数の自動実行の設定
```sql
SELECT cron.schedule('roll_up_1min',
    '* * * * *',
    'SELECT rollup_minutely();'
);
```

# 10 毎時ロールアップ用関数
## 10.1 最終ロールアップ日時の初期化
```sql
INSERT INTO latest_rollup_1hour VALUES ('10-10-1901');
```

## 10.2 関数の作成
```sql
CREATE OR REPLACE FUNCTION rollup_hourly() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('hour', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1hour;
    BEGIN
        INSERT INTO sensors_1hour (
            sensor_id, sensor_name, sensed_time,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('hour', sensed_time),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1min
            WHERE date_trunc('hour', sensed_time) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id, sensor_name, sensed_time;

        UPDATE latest_rollup_1hour SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 10.3 毎時ロールアップ用関数の自動実行の設定

毎時01分に実行する想定。

```sql
SELECT cron.schedule('roll_up_1hour',
    '1 * * * *',
    'SELECT rollup_hourly();'
);
```

# 11 日次ロールアップ用関数
## 11.1 最終ロールアップ日時の初期化
```sql
INSERT INTO latest_rollup_1day VALUES ('10-10-1901');
```

## 11.2 関数の作成
```sql
CREATE OR REPLACE FUNCTION rollup_daily() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('day', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1day;
    BEGIN
        INSERT INTO sensors_1day (
            sensor_id, sensor_name, sensed_time,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('day', sensed_time),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1hour
            WHERE date_trunc('day', sensed_time) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id, sensor_name, sensed_time;

        UPDATE latest_rollup_1day SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 11.3 日次ロールアップ用関数の自動実行の設定

毎日午前0時10分に実行する想定。

```sql
SELECT cron.schedule('roll_up_1day',
    '10 0 * * *',
    'SELECT rollup_daily();'
);
```

# 12 週次ロールアップ用関数
## 12.1 最終ロールアップ日時の初期化
```sql
INSERT INTO latest_rollup_1week VALUES ('10-10-1901');
```

## 12.2 関数の作成
```sql
CREATE OR REPLACE FUNCTION rollup_weekly() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('day', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1week;
    BEGIN
        INSERT INTO sensors_1week (
            sensor_id, sensor_name, sensed_time,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('day', now() - INTERVAL '1 day' * date_part('dow', sensed_time)),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1day
            WHERE date_trunc('day', sensed_time) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id, sensor_name, sensed_time;

        UPDATE latest_rollup_1week SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 12.3 週次ロールアップ用関数の自動実行の設定

毎週月曜午前2時00分に実行する想定。

```sql
SELECT cron.schedule('roll_up_1week',
    '0 2 * * mon',
    'SELECT rollup_weekly();'
);
```

# 13 集約の定期処理のチェック
## 13.1 毎分のロールアップ
```sql
SELECT * FROM sensors_1min LIMIT 10;
```

## 13.2 毎時のロールアップ
```sql
SELECT * FROM sensors_1hour LIMIT 10;
```
毎分のロールアップが実行済みであれば、毎時ロールアップ関数を手動で実行すれば動作が確認できる。以下、日次、週次についても同様。
```sql
SELECT rollup_hourly();
```

## 13.3 日次のロールアップ
```sql
SELECT * FROM sensors_1day LIMIT 10;
```

## 13.4 週次のロールアップ
```sql
SELECT * FROM sensors_1week LIMIT 10;
```
# 14 本番を模したダミーデータの生成 (optional)

ステップ7以降を置き換える。本番を想定したクラスタ構成のため、コストが嵩む点に注意。

ただし、過去のデータを格納する場合には古いパーティションを用意しておく必要があるため、各テーブルのパーティションを以下のように作成しておく。
```sql
SELECT create_time_partitions(
    table_name         := 'sensors',
    partition_interval := '1 day',
    start_from    := '2024-06-01'::timestamptz,
    end_at := now()
);
```

## 14.1 citus.shard_countの変更

CDBPGを新規にデプロイし、WorkerノードのvCPUの合計と同じcitus.shard_countを設定する。
Coordinatorノード: 16vCPU, 512GB
Workerノード: 16vCPU, 2TB x 4ノード

Azureポータルから、Coordinatorノードのパラメータのcitus.shard_countを64 (16vCPU x 4ノード)に変更する。

## 14.2 ダミーデータ用センサーマスター

テーブルの作成
```sql
CREATE TABLE dummy_sensor_ms(
    sensor_id bigint,
    sensor_name varchar(16)
);
```

シャードの設定
```sql
SELECT create_reference_table('dummy_sensor_ms');
```

ダミーセンサーマスターのデータの生成。ステップ7の100倍のセンサー数を想定。

```sql
INSERT INTO dummy_sensor_ms (
    sensor_id, sensor_name
)
SELECT
    i,
    concat(('{SA,SB,SC,SD,SE,RA,RB,GF,GT,CL}'::text[])[ceil(random()*10)], '-', (random() * 1000000)::int % 10000)
FROM GENERATE_SERIES(1, 102400) AS i;
```

## 14.3 ダミーデータの生成

1週間分のダミーデータを生成する。RAWデータは102,400センサー x 10,080分 = 1,032,192,000、約10億レコードとなる。全てをgenerate_series()で実行しないのは、途中でCOMMITしないとout of memoryになるため。

```sql
DO $$
    BEGIN
        FOR dd in 1..7 LOOP
            FOR dh in 0..23 LOOP
                INSERT INTO sensors (
                    sensor_id,
                    sensor_name,
                    sensed_time,
                    ingest_time,
                    sec_00, sec_01, sec_02, sec_03, sec_04, sec_05, sec_06, sec_07, sec_08, sec_09, sec_10, sec_11, sec_12, sec_13, sec_14, sec_15, sec_16, sec_17, sec_18, sec_19, sec_20, sec_21, sec_22, sec_23, sec_24, sec_25, sec_26, sec_27, sec_28, sec_29, sec_30, sec_31, sec_32, sec_33, sec_34, sec_35, sec_36, sec_37, sec_38, sec_39, sec_40, sec_41, sec_42, sec_43, sec_44, sec_45, sec_46, sec_47, sec_48, sec_49, sec_50, sec_51, sec_52, sec_53, sec_54, sec_55, sec_56, sec_57, sec_58, sec_59
                ) 
                SELECT
                    id,
                    ms.sensor_name,
                    concat('2024-06-', to_char(dd, 'FM00'), ' ', to_char(dh, 'FM00'), ':', to_char(dm, 'FM00'), ':00+00')::timestamptz,
                    concat('2024-06-', to_char(dd, 'FM00'), ' ', to_char(dh, 'FM00'), ':', to_char(dm, 'FM00'), ':00+00')::timestamptz + INTERVAL '1 minute',
                    random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random()
                FROM
                    GENERATE_SERIES(0, 59) AS dm,
                    GENERATE_SERIES(1, 102400) AS id
                JOIN dummy_sensor_ms ms ON ms.sensor_id = id
                ;
                COMMIT;
            END LOOP;
        END LOOP;
END;
$$;
```

データの生成中に、十分な負荷がかかっているかチェックすること。負荷が低い場合は生成するクエリを複数並列に実行し、CPUに適切な負荷がかかるようにしないと、余計な時間がかかる。例えば単一のクエリ（グラフの7PM以前）と、7並列のクエリ（7PM以降）では、7並列が適切なサイズであることが分かる。
![](chart.png)

また、ファイルに出力する方法もある。ただし、このセンサー数で1週間分のデータを生成すると、ファイルサイズが1TB程度になるため注意が必要。
```sql
\COPY
    (SELECT
        id,
        ms.sensor_name,
        concat('2024-06-01 ', to_char(dh, 'FM00'), ':', to_char(dm, 'FM00'), ':00+00')::timestamptz,
        concat('2024-06-01 ', to_char(dh, 'FM00'), ':', to_char(dm, 'FM00'), ':00+00')::timestamptz + INTERVAL '1 minute',
        random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random()
    FROM
        GENERATE_SERIES(0, 23) AS dh,
        GENERATE_SERIES(0, 59) AS dm,
        GENERATE_SERIES(1, 102400) AS id
    JOIN dummy_sensor_ms ms ON ms.sensor_id = id)
TO dummy_data.csv WITH CSV;
```

## 14.4 ステップ9以降の実行

pg_cronによる自動実行を設定せず、各ロールアップを手動で実行することで、実際のデータ量等を計測できる。Azureポータルからメトリックを利用する、あるいは以下のクエリーを実行する。

```sql
SELECT logicalrelid AS name,
       pg_size_pretty(citus_table_size(logicalrelid)) AS size
  FROM pg_dist_partition;
```

# 15 LTTBによる折れ線グラフ用のダウンサンプリング (optional)

LTTB (Largest Triangle Three Bucket)アルゴリズムによってダウンサンプリングすることで、少ないデータポイントでオリジナルデータの特徴的な形状を再現できる。LTTBには[各言語での実装がある](https://github.com/sveinn-steinarsson/flot-downsample)ものの、それらはPostgreSQLの外部で実行する必要があるため、PL/PGSQLで実装した例を示す。

```sql
CREATE OR REPLACE FUNCTION largest_triangle_three_buckets(data POINT[], threshold INT)
RETURNS POINT[] AS $$
DECLARE
    a INT := 1;
    next_a INT;
    max_area_point POINT;
    bucket_size DOUBLE PRECISION;
    tmp_p POINT;
    avg_x DOUBLE PRECISION;
    avg_y DOUBLE PRECISION;
    avg_range_start INT;
    avg_range_end INT;
    avg_range_length INT;
    range_offs INT;
    range_to INT;
    point_ax DOUBLE PRECISION;
    point_ay DOUBLE PRECISION;
    max_area DOUBLE PRECISION;
    area DOUBLE PRECISION;
    sampled point[] := '{}';
BEGIN
    -- Validate input data and threshold
    IF array_length(data, 1) IS NULL OR threshold <= 2 OR threshold >= array_length(data, 1) THEN
        RAISE EXCEPTION 'Invalid data or threshold';
    END IF;

    -- Initialize variables
    bucket_size := CAST(array_length(data, 1) - 2 AS DOUBLE PRECISION) / (threshold - 2);
    -- RAISE NOTICE 'bucket_size: %', bucket_size;

    -- Always include the first data point
    sampled := array_append(sampled, data[1]);

    -- Downsample the data
    FOR i IN 0..threshold - 3 LOOP
        -- Calculate the average x and y values for the next bucket
        avg_range_start := FLOOR((i + 1) * bucket_size) + 1;
        avg_range_end := LEAST(FLOOR((i + 2) * bucket_size) + 1, array_length(data, 1));
        avg_x := 0;
        avg_y := 0;
        avg_range_length := avg_range_end - avg_range_start;
        -- RAISE NOTICE 'avg_range_length: %', avg_range_length;

        FOR j IN avg_range_start..avg_range_end - 1 LOOP
            tmp_p := data[j];
            avg_x := avg_x + tmp_p[0];
            avg_y := avg_y + tmp_p[1];
        END LOOP;

        avg_x := avg_x / avg_range_length;
        avg_y := avg_y / avg_range_length;
        -- RAISE NOTICE 'avg_x: %', avg_x;
        -- RAISE NOTICE 'avg_y: %', avg_y;

        -- Determine the point that forms the largest triangle with point a and the average point
        max_area := -1;
        range_offs := FLOOR(i * bucket_size) + 1;
        range_to := FLOOR((i + 1) * bucket_size) + 1;
        tmp_p := data[a];
        point_ax := tmp_p[0];
        point_ay := tmp_p[1];

        FOR j IN range_offs..range_to - 1 LOOP
            tmp_p := data[j];
            area := ABS((point_ax - avg_x) * (tmp_p[1] - point_ay) - (point_ax - tmp_p[0]) * (avg_y - point_ay)) * 0.5;
            IF area > max_area THEN
                max_area := area;
                max_area_point := data[j];
                next_a := j;
            END IF;
        END LOOP;

        -- Add the point with the largest area to the downsampled data
        sampled := array_append(sampled, max_area_point);
        a := next_a;
    END LOOP;

    -- Always include the last data point
    sampled := array_append(sampled, data[array_length(data, 1)]);
    RETURN sampled;
END;
$$ LANGUAGE plpgsql;
```

この関数をpg_cronで例えば毎時実行することで、3600秒のデータポイントを任意のデータポイント数にダウンサンプリングできる。生成する折れ線グラフのサイズに合わせたサンプリングを行えば、小さなデータ量で特徴的な形状を表示することが可能となる。

詳細は[筆者のブログ](https://rio.st/2024/06/25/pl-pgsql%e3%81%a7%e3%83%80%e3%82%a6%e3%83%b3%e3%82%b5%e3%83%b3%e3%83%97%e3%83%aa%e3%83%b3%e3%82%b0%e3%81%97%e3%81%9f%e3%81%84/)、および[レポジトリ](https://github.com/rioriost/lttb-sql/tree/main)を参照のこと。
