use customer_analytics;
select * from customer_behavior;

-- CREATING DIMENTION TABLES
----------------------------------------
-- 1.  Dim_Customer Table
----------------------------------------
create table dim_customer (
    customer_key int identity(1,1) primary key,
    customer_id varchar(50) unique,
    age int,
    gender varchar(20),
    signup_date date,
    loyalty_status varchar(10),
    membership_join_date date,
    location_key int
);

-- insert data
insert into dim_customer (
    customer_id,
    age,
    gender,
    signup_date,
    loyalty_status,
    membership_join_date,
    location_key
)
select
    t.customer_id,
    t.age,
    t.gender,
    t.signup_date,
    t.loyalty_status,
    t.membership_join_date,
    l.location_key
from (
    -- Step 1: Aggregate raw table FIRST
    select
        [customer id] as customer_id,
        max(age) as age,
        max(gender) as gender,
        min([signup date]) as signup_date,
        max([loyality member]) as loyalty_status,
        min([member ship join date]) as membership_join_date,
        max(location) as location
    from customer_behavior
    group by [customer id]
) t
join dim_location l
    on t.location = l.location;
-----------------------------------------
-- 2 dim_product Table
-----------------------------------------
CREATE TABLE dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    item_purchased VARCHAR(200),
    brand VARCHAR(100),
    category VARCHAR(100)
);
-- insert Data
INSERT INTO dim_product (item_purchased, brand, category)
SELECT DISTINCT
    [item purchased],
    brand,
    category
FROM customer_behavior;

-----------------------------------------------
-- 3 dim_location Table
-----------------------------------------------
create table dim_location (
    location_key int identity(1,1) primary key,
    location varchar(100) unique
);

-- insert Data
insert into dim_location (location)
select distinct location
from customer_behavior;

---------------------------------------------
-- 4 dim_payment Table
---------------------------------------------
create table dim_payment (
    payment_key int identity(1,1) primary key,
    payment_method varchar(50),
    preferred_payment_method varchar(50),
    card_bank varchar(50),
    emi varchar(10),
    emi_tenure int
);

-- insert Data
insert into dim_payment (
    payment_method,
    preferred_payment_method,
    card_bank,
    emi,
    emi_tenure
)
select distinct
    [payment method],
    [preferred payment method],
    [card bank],
    emi,
    [emi tenure]
from customer_behavior;

--------------------------------------------
-- 5 dim_channel Table
--------------------------------------------
create table dim_channel (
    channel_key int identity(1,1) primary key,
    channel varchar(50),
    campaign varchar(100),
    promo_used varchar(10),
    discount_applied varchar(10)
);

-- insert Data
insert into dim_channel (
    channel,
    campaign,
    promo_used,
    discount_applied
)
select distinct
    channel,
    campaign,
    [promo used],
    [discount applied]
from customer_behavior;

--------------------------------------------
-- 6 dim_date Table
--------------------------------------------
create table dim_date (
    date_key date primary key,
    year int,
    quarter int,
    month int,
    month_name varchar(20),
    day int,
    week_number int
);

-- insert Data
insert into dim_date
select distinct
    [purchase date],
    year([purchase date]),
    datepart(quarter, [purchase date]),
    month([purchase date]),
    datename(month, [purchase date]),
    day([purchase date]),
    datepart(week, [purchase date])
from customer_behavior;
----------------------------------------------
-- 7 fact_sales Table
----------------------------------------------
create table fact_sales (
    order_id varchar(50),

    customer_key int,
    product_key int,
    date_key date,
    channel_key int,
    payment_key int,

    quantity int,
    revenue float,
    cost float,
    profit float,
    gross_profit float,
    loyalty_points int,
    redeem float
);
-- insert Data
insert into fact_sales (
    order_id,
    customer_key,
    product_key,
    date_key,
    channel_key,
    payment_key,
    quantity,
    revenue,
    cost,
    profit,
    gross_profit,
    loyalty_points,
    redeem
)
select
    r.[order id],
    c.customer_key,
    p.product_key,
    r.[purchase date],
    ch.channel_key,
    pay.payment_key,
    r.quantity,
    r.revenue,
    r.cost,
    r.profit,
    r.[gross profit],
    r.[loyality points],
    r.redem
from customer_behavior r
join dim_customer c
    on r.[customer id] = c.customer_id
join dim_product p
    on r.[item purchased] = p.item_purchased
join dim_channel ch
    on r.channel = ch.channel
   and r.campaign = ch.campaign
   and r.[promo used] = ch.promo_used
   and r.[discount applied] = ch.discount_applied
join dim_payment pay
    on r.[payment method] = pay.payment_method
   and r.[preferred payment method] = pay.preferred_payment_method
   and r.[card bank] = pay.card_bank
   and r.emi = pay.emi
   and r.[emi tenure] = pay.emi_tenure;


ALTER TABLE fact_sales
ADD shipping_type VARCHAR(50),
review_rating FLOAT;

UPDATE fs
SET 
    fs.shipping_type = r.[shipping type],
    fs.review_rating = r.[review rating]
FROM fact_sales fs
JOIN customer_behavior r
ON fs.order_id = r.[order id];

UPDATE fs
SET fs.specification_key = ds.specification_key
FROM fact_sales fs
JOIN customer_behavior r
    ON fs.order_id = r.[order id]
JOIN dim_product p
    ON r.[item purchased] = p.item_purchased
JOIN dim_specification ds
    ON ds.product_key = p.product_key
   AND ds.ram = r.ram
   AND ds.memory = r.memory
   AND ds.processor = r.processor;

-----------------------------------------------
-- 8 dim_specification Table
-----------------------------------------------
CREATE TABLE dim_specification (
    specification_key INT IDENTITY(1,1) PRIMARY KEY,
    product_key INT,
    processor VARCHAR(100),
    ram VARCHAR(50),
    memory VARCHAR(50),
    os VARCHAR(50),
    graphics VARCHAR(100),
    color_variant VARCHAR(50)
);

-- insert data
INSERT INTO dim_specification (
    product_key,
    processor,
    ram,
    memory,
    os,
    graphics,
    color_variant
)
SELECT DISTINCT
    p.product_key,
    r.processor,
    r.ram,
    r.memory,
    r.os,
    r.graphics,
    r.[color variant]
FROM customer_behavior r
JOIN dim_product p
    ON r.[item purchased] = p.item_purchased;

-------------------------------------------------
-- add foreign keys
-------------------------------------------------
ALTER TABLE fact_sales
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_key)
REFERENCES dim_customer(customer_key);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_product
FOREIGN KEY (product_key)
REFERENCES dim_product(product_key);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_date
FOREIGN KEY (date_key)
REFERENCES dim_date(date_key);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_channel
FOREIGN KEY (channel_key)
REFERENCES dim_channel(channel_key);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_payment
FOREIGN KEY (payment_key)
REFERENCES dim_payment(payment_key);

ALTER TABLE dim_customer
ADD CONSTRAINT fk_location
FOREIGN KEY (location_key)
REFERENCES dim_location(location_key);

ALTER TABLE fact_sales
ADD specification_key INT;


-- Checking the tables
select * from dim_channel;
select * from dim_customer;
select * from dim_date;
select * from dim_location;
select * from dim_payment;
select * from dim_product;
select * from fact_sales;
select * from dim_specification;


create database a;