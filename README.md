# このハンズオンラボが想定するシナリオについて

工場や発電所、スマートビルディングなど、数万個あるセンサーが毎秒記録したデータを毎分、60秒間分をまとめて送出してくるシナリオを想定している。

センサーがグローバルに配置されている場合、Cosmos DB for PostgreSQL (CDBPG)はグローバル分散に対応しないため、Cosmos DB for NoSQLを用いてMulti-region Writeを実装すべきだが、Cosmos DB for NoSQLで受信後、ChangeFeedによりキックされたFunction等で特定の（例えばAzure東日本）に配置されたCDBPGに集約するシナリオは十分に考えられるし、実際にそのようなデザインのシステムは本番稼働している。

ハンズオンでは最小構成のクラスタをデプロイするが、センサーの数が増えた場合には以下の点に注意が必要。

サーバーパラメータのcitus.shard_countをデフォルトの32から、クラスタを構成するWorkerノードの総vCPU数と揃える。例えば、16vCPUのWorkerが10ノード存在するなら、citus.shard_countは160もしくは、それ以上の数値を設定する。

1. センサーが1,024個あり、このハンズオンのようにsensor_idをそのままシャードキーにする場合、シャードは1024個となる。
2. citus.shard_countが32の場合には、シャードキーは32のレンジ（32bitハッシュの値の範囲を32分割する）となり、各レンジがWorkerノードに割り当てられるため、3.2レンジ/ノード = 32シャード/ノードとなる。
3. 一方でvCPUは16であるから2シャード/vCPUとなり、データの到着頻度が高い場合には性能不足となることが考えられる。CPUのキャッシュヒット率などを考慮すると1シャード=1vCPUが理想だが、コストとの勘案となる。
4. Workerノードをスケールアウトする（10→20ノード）か、スケールアップする（16→32vCPU）かが考えられるが、データサイズが大きくIO負荷が高い場合はスケールアウトを選択しSSDの台数を増やし、そうで無い場合はスケールアップを選択するのが一般的な指針となる。
5. ノード数を増やす（クラスタスケールアウト）、SSDの容量を増やす（ストレージスケールアップ）、のいずれもトータルのIOPSも向上するが、いずれもスケールインが出来ない点にも注意。

# 0. Cosmos DB for PostgreSQL (CDBPG) について
CDBPGの基本的な操作については、ここでは触れない。

[ハンズオンラボ](https://github.com/tahayaka-microsoft/CosmosDBforPG_HoL/)を事前に受講しているか、独習済みであることが必須。

またこのハンズオンラボの内容は、上記リンクのハンズオンラボの「リアルタイムダッシュボード」の拡張版なので、基本的な事柄についての理解はそちらに譲る。

# 1. CDBPGのデプロイ
ハンズオンは、2 Workerノード(4vCPUs, 512GB)をデプロイし、デフォルトのサーバーパラメーターで実施する。4vCPUではAUTO_VACUUM時に性能のインパクトが大きいため、本番では8vCPU以上を設定すること。業務時間外にAUTO_VACUUMを実行できるのであればその限りではないものの、一般にIoTのシナリオではデータ到着のシーズナリティが低いため、8vCPU以上を推奨する。

# 2. RAWデータテーブル
## 2.1 テーブルの作成
sensor_nameをマスターに分離することも考えられる。ダミーデータではマスターを使って、複合ユニーク制約を模している。

sensor_idとsensor_nameは複合ユニーク制約のはずだが、ここでは実装しない。UNIQUE(sensor_id, sensor_name)

00〜59秒のデータがカラムに分離しているのは、columnar storageにおける圧縮率向上のため。array型でも同じようなデータが並ぶのであれば、array型で定義しても良い。その場合、後段のaggregationにおけるUNNEST処理などが変わるので注意。CREATE TABLE実行時にUSING COLUMNARキーワードを付加することで、HEAPをそもそも用いない構成も可能。圧縮による性能向上はかなり絶大なので、パフォーマンスベンチマークを実施してから決定しても良い。
```
CREATE TABLE sensors(
    sensor_id bigint NOT NULL,
    sensor_name text NOT NULL,
    sensed_at timestamptz NOT NULL,
    sec_00 float,
    sec_01 float,
    sec_02 float,
    sec_03 float,
    sec_04 float,
    sec_05 float,
    sec_06 float,
    sec_07 float,
    sec_08 float,
    sec_09 float,
    sec_10 float,
    sec_11 float,
    sec_12 float,
    sec_13 float,
    sec_14 float,
    sec_15 float,
    sec_16 float,
    sec_17 float,
    sec_18 float,
    sec_19 float,
    sec_20 float,
    sec_21 float,
    sec_22 float,
    sec_23 float,
    sec_24 float,
    sec_25 float,
    sec_26 float,
    sec_27 float,
    sec_28 float,
    sec_29 float,
    sec_30 float,
    sec_31 float,
    sec_32 float,
    sec_33 float,
    sec_34 float,
    sec_35 float,
    sec_36 float,
    sec_37 float,
    sec_38 float,
    sec_39 float,
    sec_40 float,
    sec_41 float,
    sec_42 float,
    sec_43 float,
    sec_44 float,
    sec_45 float,
    sec_46 float,
    sec_47 float,
    sec_48 float,
    sec_49 float,
    sec_50 float,
    sec_51 float,
    sec_52 float,
    sec_53 float,
    sec_54 float,
    sec_55 float,
    sec_56 float,
    sec_57 float,
    sec_58 float,
    sec_59 float
) PARTITION BY RANGE (sensed_at);
```

## 2.1 インデックスの作成
```
CREATE INDEX sensor_name_index ON sensors (sensor_name);
```

## 2.2 シャードの設定
```
SELECT create_distributed_table('sensors', 'sensor_id');
```

以下のクエリでシャード設定が確認できる。
```
SELECT * FROM citus_shards;
```

## 2.3 パーティションの設定

毎時も可能だが、パーティション数が多くなりすぎる可能性があるため、総データ容量、データのボリューム、データライフサイクルを勘案して決定すべし。
```
SELECT create_time_partitions(
    table_name         := 'sensors',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

実行後に、\dで作成したテーブルを確認する。
```
\d
```

パーティションの管理については以下。
7日分のパーティションを作成
```
-- パーティションの削除
-- drop_old_time_partitions
-- heap / columnarの切り替え
-- alter_old_partitions_set_access_method
```

## 2.4 パーティション管理の自動化
7日分のパーティションの作成の自動化
```
SELECT cron.schedule('create-partitions_sensors',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

設定したcronジョブについてのクエリは以下。
```
-- ジョブの一覧
SELECT * FROM cron.job;
```
```
-- ジョブIDでジョブをスケジュールから削除
-- SELECT cron.unschedule(job id);
```

5日より古いパーティションの圧縮
```
SELECT cron.schedule('compress-partitions_sensors',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors',
        now() - interval '5 days', 'columnar') $$
);
```

# 3 毎分ロールアップ用テーブル
## 3.1 テーブルの作成
```
CREATE TABLE sensors_1min(
    sensor_id bigint,
    sensor_name text,
    sensed_at timestamptz,
    avg float,
    min float,
    max float
    CHECK (sensed_at = date_trunc('minute', sensed_at))
) PARTITION BY RANGE (sensed_at);
```

## 3.2 インデックスの作成
```
CREATE INDEX sensor_name_1min_index ON sensors_1min (sensor_name);
```

## 3.3 シャードの設定
```
SELECT create_distributed_table('sensors_1min', 'sensor_id');
```

## 3.4 パーティションの設定
7日分のパーティションを作成
```
SELECT create_time_partitions(
    table_name         := 'sensors_1min',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 3.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```
SELECT cron.schedule('create-partitions_sensors_1min',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1min',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```
SELECT cron.schedule('compress-partitions_sensors_1min',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1min',
        now() - interval '5 days', 'columnar') $$
);
```

## 3.6 最後にロールアップした時間（分）の記録
テーブルの作成
```
CREATE TABLE latest_rollup_1min (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('minute', rolled_at))
);
```

# 4 毎時ロールアップ用テーブル
## 4.1 テーブルの作成
```
CREATE TABLE sensors_1hour(
    sensor_id bigint,
    sensor_name text,
    sensed_at timestamptz,
    avg float,
    min float,
    max float,
    CHECK (sensed_at = date_trunc('hour', sensed_at))
) PARTITION BY RANGE (sensed_at);
```

## 4.2 インデックスの作成
```
CREATE INDEX sensor_name_1hour_index ON sensors_1hour (sensor_name);
```

## 4.3 シャードの設定
```
SELECT create_distributed_table('sensors_1hour', 'sensor_id');
```

## 4.4 パーティションの設定
7日分のパーティションを作成
```
SELECT create_time_partitions(
    table_name         := 'sensors_1hour',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 4.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```
SELECT cron.schedule('create-partitions_sensors_1hour',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1hour',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```
SELECT cron.schedule('compress-partitions_sensors_1hour',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1hour',
        now() - interval '5 days', 'columnar') $$
);
```

## 4.6 最後にロールアップした時間（時）の記録
テーブルの作成
```
CREATE TABLE latest_rollup_1hour (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('hour', rolled_at))
);
```

# 5 日次ロールアップ用テーブル
## 5.1 テーブルの作成
```
CREATE TABLE sensors_1day(
    sensor_id bigint,
    sensor_name text,
    sensed_at timestamptz,
    avg float,
    min float,
    max float,
    CHECK (sensed_at = date_trunc('day', sensed_at))
) PARTITION BY RANGE (sensed_at);
```

## 5.2 インデックスの作成
```
CREATE INDEX sensor_name_1day_index ON sensors_1day (sensor_name);
```

## 5.3 シャードの設定
```
SELECT create_distributed_table('sensors_1day', 'sensor_id');
```

## 5.4 パーティションの設定
7日分のパーティションを作成
```
SELECT create_time_partitions(
    table_name         := 'sensors_1day',
    partition_interval := '1 day',
    end_at             := now() + '7 days'
);
```

## 5.5 パーティション管理の自動化
7日分のパーティションの作成の自動化
```
SELECT cron.schedule('create-partitions_sensors_1day',
    '@daily',
    $$SELECT create_time_partitions(table_name:='sensors_1day',
        partition_interval:= '1 day',
        end_at:= now() + '7 days') $$
);
```

5日より古いパーティションの圧縮
```
SELECT cron.schedule('compress-partitions_sensors_1day',
    '@daily',
    $$CALL alter_old_partitions_set_access_method('sensors_1day',
        now() - interval '5 days', 'columnar') $$
);
```

## 5.6 最後にロールアップした時間（日）の記録
テーブルの作成
```
CREATE TABLE latest_rollup_1day (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);
```

# 6 週次ロールアップ用テーブル
## 6.1 テーブルの作成
```
CREATE TABLE sensors_1week(
    sensor_id bigint,
    sensor_name text,
    sensed_at timestamptz,
    avg float,
    min float,
    max float,
    CHECK (sensed_at = date_trunc('day', sensed_at))
) PARTITION BY RANGE (sensed_at);
```

## 6.2 インデックスの作成
```
CREATE INDEX sensor_name_1week_index ON sensors_1week (sensor_name);
```

## 6.3 シャードの設定
```
SELECT create_distributed_table('sensors_1week', 'sensor_id');
```

## 6.4 パーティションの設定
2週分のパーティションを作成
```
SELECT create_time_partitions(
    table_name         := 'sensors_1week',
    partition_interval := '1 week',
    end_at             := now() + '2 weeks'
);
```

## 6.5 パーティション管理の自動化
2週分のパーティションの作成の自動化
```
SELECT cron.schedule('create-partitions_sensors_1week',
    '@weekly',
    $$SELECT create_time_partitions(table_name:='sensors_1week',
        partition_interval:= '1 week',
        end_at:= now() + '2 weeks') $$
);
```

5週より古いパーティションの圧縮
```
SELECT cron.schedule('compress-partitions_sensors_1week',
    '@weekly',
    $$CALL alter_old_partitions_set_access_method('sensors_1week',
        now() - interval '5 weeks', 'columnar') $$
);
```

## 6.6 最後にロールアップした時間（週）の記録
テーブルの作成
```
CREATE TABLE latest_rollup_1week (
    rolled_at timestamptz PRIMARY KEY,
    CHECK (rolled_at = date_trunc('day', rolled_at))
);
```

# 7 毎分ロールアップ用関数
## 7.1 最終ロールアップ日時の初期化
```
INSERT INTO latest_rollup_1min VALUES ('10-10-1901');
```

## 7.2 関数の作成
```
CREATE OR REPLACE FUNCTION rollup_minutely() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('minute', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1min;
    BEGIN
        INSERT INTO sensors_1min (
            sensor_id, sensor_name, sensed_at,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('minute', sensed_at),
            AVG(vals), MIN(vals), MAX(vals) FROM (
                SELECT sensor_id, sensor_name, sensed_at, UNNEST(ARRAY[sec_00, sec_01, sec_02, sec_03, sec_04, sec_05, sec_06, sec_07, sec_08, sec_09, sec_10, sec_11, sec_12, sec_13, sec_14, sec_15, sec_16, sec_17, sec_18, sec_19, sec_20, sec_21, sec_22, sec_23, sec_24, sec_25, sec_26, sec_27, sec_28, sec_29, sec_30, sec_31, sec_32, sec_33, sec_34, sec_35, sec_36, sec_37, sec_38, sec_39, sec_40, sec_41, sec_42, sec_43, sec_44, sec_45, sec_46, sec_47, sec_48, sec_49, sec_50, sec_51, sec_52, sec_53, sec_54, sec_55, sec_56, sec_57, sec_58, sec_59]) AS vals
                FROM sensors
                WHERE date_trunc('minute', sensed_at) <@
                tstzrange(last_rollup_time, curr_rollup_time, '(]')
                ) AS unnested
                GROUP BY sensor_id, sensor_name, sensed_at;

        UPDATE latest_rollup_1min SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

作成後に実行してみる。
```
SELECT rollup_minutely();
```

## 7.3 毎分ロールアップ用関数の自動実行の設定
```
SELECT cron.schedule('roll_up_1min',
    '* * * * *',
    'SELECT rollup_minutely();'
);
```

# 8 毎時ロールアップ用関数
## 8.1 最終ロールアップ日時の初期化
```
INSERT INTO latest_rollup_1hour VALUES ('10-10-1901');
```

## 8.2 関数の作成
```
CREATE OR REPLACE FUNCTION rollup_hourly() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('hour', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1hour;
    BEGIN
        INSERT INTO sensors_1hour (
            sensor_id, sensor_name, sensed_at,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('hour', sensed_at),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1min
            WHERE date_trunc('hour', sensed_at) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id;

        UPDATE latest_rollup_1hour SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 8.3 毎時ロールアップ用関数の自動実行の設定

毎時01分に実行する想定。

```
SELECT cron.schedule('roll_up_1hour',
    '1 * * * *',
    'SELECT rollup_hourly();'
);
```

# 9 日次ロールアップ用関数
## 9.1 最終ロールアップ日時の初期化
```
INSERT INTO latest_rollup_1day VALUES ('10-10-1901');
```

## 9.2 関数の作成
```
CREATE OR REPLACE FUNCTION rollup_daily() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('day', now());
        last_rollup_time timestamptz := rolled_at from latest_rollup_1day;
    BEGIN
        INSERT INTO sensors_1day (
            sensor_id, sensor_name, sensed_at,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('day', sensed_at),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1hour
            WHERE date_trunc('day', sensed_at) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id;

        UPDATE latest_rollup_1day SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 9.3 日次ロールアップ用関数の自動実行の設定

毎日午前0時10分に実行する想定。

```
SELECT cron.schedule('roll_up_1day',
    '10 0 * * *',
    'SELECT rollup_daily();'
);
```

# 10 週次ロールアップ用関数
## 10.1 最終ロールアップ日時の初期化
```
INSERT INTO latest_rollup_1week VALUES ('10-10-1901');
```

## 10.2 関数の作成
```
CREATE OR REPLACE FUNCTION rollup_weekly() RETURNS void AS $$
    DECLARE
        curr_rollup_time timestamptz := date_trunc('day', now() - INTERVAL '1 day' * date_part('dow', sensed_at));
        last_rollup_time timestamptz := rolled_at from latest_rollup_1week;
    BEGIN
        INSERT INTO sensors_1week (
            sensor_id, sensor_name, sensed_at,
            avg, min, max
        )
        SELECT
            sensor_id,
            sensor_name,
            date_trunc('day', now() - INTERVAL '1 day' * date_part('dow', sensed_at)),
            AVG(avg), MIN(min), MAX(max)
            FROM sensors_1day
            WHERE date_trunc('day', sensed_at) <@
            tstzrange(last_rollup_time, curr_rollup_time, '(]')
            GROUP BY sensor_id;

        UPDATE latest_rollup_1week SET rolled_at = curr_rollup_time;
    END;
$$ LANGUAGE plpgsql;
```

## 10.3 週次ロールアップ用関数の自動実行の設定

毎週月曜午前2時00分に実行する想定。

```
SELECT cron.schedule('roll_up_1week',
    '0 2 * * mon',
    'SELECT rollup_weekly();'
);
```

# 11 ダミーデータ用センサーマスター
# 11.1 テーブルの作成
以下はここまでの設定で正しく動作するかを確認する手順。本番データはファイルなどでシステムに到着し、Storage TriggerなどでキックされたFunctions等がingestする。sensor_idやsensor_nameは元データの段階で一意性制約を満たしている想定だが、テーブル定義として制約を課しておくことに問題はない。

```
CREATE TABLE dummy_sensor_ms(
    sensor_id bigint,
    sensor_name text
);
```

## 11.2 シャードの設定

マスターデータなので、Referenceテーブルとする。Referenceテーブルは、Distributedテーブルの亜種で、同一のシャードが全てのノードに置かれる。

```
SELECT create_reference_table('dummy_sensor_ms');
```

## 11.3 ダミーセンサーマスターのデータの生成

次のステップのセンサー数（generate_seriesの引数）と揃えること。

```
INSERT INTO dummy_sensor_ms (
    sensor_id, sensor_name
)
SELECT
    i,
    concat(('{SA,SB,SC,SD,SE,RA,RB,GF,GT,CL}'::text[])[ceil(random()*10)], '-', (random() * 1000000)::int % 10000)
FROM GENERATE_SERIES(1, 1024) AS i;
```
       
# 12 ダミーデータの生成

以下の内容のdummy_generator.sqlを作成し、psql -f dummy_generator.sqlで実行（バックグラウンド実行）する。クラウドシェルのエディタ、あるいはローカルマシン上に作成する方法のいずれも可能。

```
DO $$
BEGIN LOOP
    INSERT INTO sensors (
        sensor_id,
        sensor_name,
        sensed_at,
        sec_00, sec_01, sec_02, sec_03, sec_04, sec_05, sec_06, sec_07, sec_08, sec_09, sec_10, sec_11, sec_12, sec_13, sec_14, sec_15, sec_16, sec_17, sec_18, sec_19, sec_20, sec_21, sec_22, sec_23, sec_24, sec_25, sec_26, sec_27, sec_28, sec_29, sec_30, sec_31, sec_32, sec_33, sec_34, sec_35, sec_36, sec_37, sec_38, sec_39, sec_40, sec_41, sec_42, sec_43, sec_44, sec_45, sec_46, sec_47, sec_48, sec_49, sec_50, sec_51, sec_52, sec_53, sec_54, sec_55, sec_56, sec_57, sec_58, sec_59
    ) 
    SELECT
        i,
        ms.sensor_name,
        now(),
        random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random()
    FROM GENERATE_SERIES(1, 1024) AS i
    JOIN dummy_sensor_ms ms ON ms.sensor_id = i
    ;
    COMMIT;
    PERFORM pg_sleep(60);
END LOOP;
END $$;
```

# 12.1 集約の定期処理のチェック
