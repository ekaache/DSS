create table customer (
    customer_id int primary key,
    first_name varchar,
    last_name varchar,
    gender varchar,
    DOB date,
    job_title VARCHAR,
    job_industry_category varchar,
    wealth_segment varchar,
    deceased_indicator varchar,
    owns_car varchar,
    address varchar,
    postcode varchar,
    state varchar,
    country varchar,
    property_valuation int
);

create table product (
    product_id int,
    brand varchar,
    product_line varchar,
    product_class varchar,
    product_size varchar,
    list_price decimal,
    standard_cost decimal
);

create table orders (
    order_id int primary key,
    customer_id int,
    order_date date,
    online_order boolean,
    order_status varchar
);

create table order_items (
    order_item_id int primary key,
    order_id int,
    product_id int,
    quantity int,
    item_list_price_at_sale decimal,
    item_standard_cost_at_sale decimal
);


create table product_cor as
 select *
 from (
  select *
   ,row_number() over(partition by product_id order by list_price desc) as rn
  from product)
 where rn = 1
 

 -- 1. Вывести все уникальные бренды, у которых есть хотя бы один продукт со стандартной стоимостью выше 1500 долларов, и суммарными продажами не менее 1000 единиц.
 
select distinct brand
from product_cor 
where standard_cost > 1500
and brand in (
    select brand
    from product_cor
    join order_items on product_cor.product_id = order_items.product_id
    group by brand
    having sum(order_items.quantity) >= 1000
);
 

 -- 2. Для каждого дня в диапазоне с 2017-04-01 по 2017-04-09 включительно вывести количество подтвержденных онлайн-заказов и количество уникальных клиентов, совершивших эти заказы.
 
 select 
    order_date,
    count(*) as order_count,
    count(distinct customer_id) as unique_customers
from orders 
where order_date between '2017-04-01' and '2017-04-09'
    and online_order = true
    and order_status = 'Approved'
group by order_date
order by order_date;
 

-- 3. Вывести профессии клиентов: из сферы IT, чья профессия начинается с Senior; из сферы Financial Services, чья профессия начинается с Lead. Для обеих групп учитывать только клиентов старше 35 лет. Объединить выборки с помощью UNION ALL.
 
select job_title
from customer
where job_industry_category = 'IT' 
    and job_title like 'Senior%'
    and extract(year from age(current_date, DOB)) > 35
union all
select job_title
from customer
where job_industry_category = 'Financial Services' 
    and job_title like 'Lead%'
    and extract(year from age(current_date, DOB)) > 35;
 

-- 4. Вывести бренды, которые были куплены клиентами из сферы Financial Services, но не были куплены клиентами из сферы IT.

select distinct product_cor.brand
from product_cor
join order_items on product_cor.product_id = order_items.product_id
join orders on order_items.order_id = orders.order_id
join customer on orders.customer_id = customer.customer_id
where customer.job_industry_category = 'Financial Services'
except
select distinct product_cor.brand
from product_cor
join order_items on product_cor.product_id = order_items.product_id
join orders on order_items.order_id = orders.order_id
join customer on orders.customer_id = customer.customer_id
where customer.job_industry_category = 'IT';
 
 
-- 5. Вывести 10 клиентов (ID, имя, фамилия), которые совершили наибольшее количество онлайн-заказов (в штуках) брендов Giant Bicycles, Norco Bicycles, Trek Bicycles, при условии, что они активны и имеют оценку имущества (property_valuation) выше среднего среди клиентов из того же штата.

select
    customer.customer_id,
    customer.first_name,
    customer.last_name,
    count(distinct orders.order_id) as order_count
from customer
join orders on customer.customer_id = orders.customer_id
join order_items on orders.order_id = order_items.order_id
join product_cor on order_items.product_id = product_cor.product_id
where product_cor.brand in ('Giant Bicycles', 'Norco Bicycles', 'Trek Bicycles')
    and orders.online_order = true
    and customer.deceased_indicator = 'N'
    and customer.property_valuation > (
        select AVG(property_valuation) 
        from customer c2 
        where c2.state = customer.state
    )
group by customer.customer_id, customer.first_name, customer.last_name
order by order_count desc
limit 10;
 

-- 6. Вывести всех клиентов (ID, имя, фамилия), у которых нет подтвержденных онлайн-заказов за последний год, но при этом они владеют автомобилем и их сегмент благосостояния не Mass Customer.
 
select 
    customer_id,
    first_name,
    last_name
from customer
where owns_car = 'Yes'
    and wealth_segment != 'Mass Customer'
    and customer_id not in (
        select customer_id
        from orders
        where online_order = true
            and order_status = 'Approved'
            and order_date >= current_date - interval '1 year'
    );
 
 
 -- 7. Вывести всех клиентов из сферы 'IT' (ID, имя, фамилия), которые купили 2 из 5 продуктов с самой высокой list_price в продуктовой линейке Road.
 
select
    customer.customer_id,
    customer.first_name,
    customer.last_name
from customer
join orders on customer.customer_id = orders.customer_id
join order_items on orders.order_id = order_items.order_id
join product_cor on order_items.product_id = product_cor.product_id
where customer.job_industry_category = 'IT'
    and product_cor.product_line = 'Road'
    and product_cor.product_id in (
        select product_id 
        from product_cor 
        where product_line = 'Road' 
        order by list_price desc 
        limit 5
    )
group by customer.customer_id, customer.first_name, customer.last_name
having count(distinct product_cor.product_id) >= 2;
 
 
-- 8. Вывести клиентов (ID, имя, фамилия, сфера деятельности) из сфер IT или Health, которые совершили не менее 3 подтвержденных заказов в период 2017-01-01 по 2017-03-01, и при этом их общий доход от этих заказов превышает 10 000 долларов. Разделить вывод на две группы (IT и Health) с помощью UNION.
 
select 
    customer.customer_id,
    customer.first_name,
    customer.last_name,
    customer.job_industry_category
from customer
join orders on customer.customer_id = orders.customer_id
join order_items on orders.order_id = order_items.order_id
where customer.job_industry_category = 'IT'
    and orders.order_status = 'Approved'
    and orders.order_date between '2017-01-01' and '2017-03-01'
group by customer.customer_id, customer.first_name, customer.last_name, customer.job_industry_category
having count(distinct orders.order_id) >= 3
    and sum(order_items.quantity * order_items.item_list_price_at_sale) > 10000
UNION
select 
    customer.customer_id,
    customer.first_name,
    customer.last_name,
    customer.job_industry_category
from customer
join orders on customer.customer_id = orders.customer_id
join order_items on orders.order_id = order_items.order_id
where customer.job_industry_category = 'Health'
    and orders.order_status = 'Approved'
    and orders.order_date between '2017-01-01' and '2017-03-01'
group by customer.customer_id, customer.first_name, customer.last_name, customer.job_industry_category
having count(distinct orders.order_id) >= 3
    and sum(order_items.quantity * order_items.item_list_price_at_sale) > 10000;
 
 