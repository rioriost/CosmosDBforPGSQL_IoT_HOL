CREATE TABLE dummy_sensor_ms(
    sensor_id bigint,
    sensor_name varchar(16)
);

SELECT create_reference_table('dummy_sensor_ms');

INSERT INTO dummy_sensor_ms (
    sensor_id, sensor_name
)
SELECT
    i,
    concat(('{SA,SB,SC,SD,SE,RA,RB,GF,GT,CL}'::text[])[ceil(random()*10)], '-', (random() * 1000000)::int % 10000)
FROM GENERATE_SERIES(1, 1024) AS i;
