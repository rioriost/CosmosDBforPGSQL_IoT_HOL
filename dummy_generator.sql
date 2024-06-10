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
        now(),
        random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random(), random()
    FROM GENERATE_SERIES(1, 1024) AS i
    JOIN dummy_sensor_ms ms ON ms.sensor_id = i
    ;
    COMMIT;
    PERFORM pg_sleep(60);
END LOOP;
END $$;
