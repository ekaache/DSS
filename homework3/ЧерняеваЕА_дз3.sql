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
 
 
-- 1. Вывести распределение (количество) клиентов по сферам деятельности, отсортировав результат по убыванию количества.

select job_industry_category, count(*) as customer_count
from customer
group by job_industry_category
order by customer_count desc;
 
-- 2. Найти общую сумму дохода (list_price*quantity) по всем подтвержденным заказам за каждый месяц по сферам деятельности клиентов. Отсортировать результат по году, месяцу и сфере деятельности.

select 
    date_trunc('month', o.order_date) as month,
    c.job_industry_category,
    sum(oi.item_list_price_at_sale * oi.quantity) as revenue
from orders o
join order_items oi on o.order_id = oi.order_id
join customer c on o.customer_id = c.customer_id
where o.order_status = 'Approved'
group by month, c.job_industry_category
order by month, c.job_industry_category;

-- 3. Вывести количество уникальных онлайн-заказов для всех брендов в рамках подтвержденных заказов клиентов из сферы IT. Включить бренды, у которых нет онлайн-заказов от IT-клиентов, — для них должно быть указано количество 0.

select
    p.brand,
    count(distinct o.order_id) as online_orders
from product_cor p
left join order_items oi on p.product_id = oi.product_id
left join orders o on oi.order_id = o.order_id
left join customer c on o.customer_id = c.customer_id
where o.online_order = true 
    and c.job_industry_category = 'IT'
    and o.order_status = 'Approved'
group by p.brand
order by online_orders desc;

-- 4. Найти по всем клиентам: сумму всех заказов (общего дохода), максимум, минимум и количество заказов, а также среднюю сумму заказа по каждому клиенту. Отсортировать результат по убыванию суммы всех заказов и количества заказов. Выполнить двумя способами: используя только GROUP BY и используя только оконные функции. Сравнить результат.

-- способ 1
select
    c.customer_id,
    c.first_name,
    c.last_name,
    sum(oi.item_list_price_at_sale * oi.quantity) as total,
    max(oi.item_list_price_at_sale * oi.quantity) as max_order,
    min(oi.item_list_price_at_sale * oi.quantity) as min_order,
    count(o.order_id) as orders_count,
    avg(oi.item_list_price_at_sale * oi.quantity) as avg_order
from customer c
left join orders o on c.customer_id = o.customer_id
left join order_items oi on o.order_id = oi.order_id
group by c.customer_id, c.first_name, c.last_name
order by total desc, orders_count desc;

-- способ 2
select distinct
    c.customer_id,
    c.first_name,
    c.last_name,
    sum(oi.item_list_price_at_sale * oi.quantity) over (partition by c.customer_id) as total,
    max(oi.item_list_price_at_sale * oi.quantity) over (partition by c.customer_id) as max_order,
    min(oi.item_list_price_at_sale * oi.quantity) over (partition by c.customer_id) as min_order,
    count(o.order_id) over (partition by c.customer_id) as orders_count,
    avg(oi.item_list_price_at_sale * oi.quantity) over (partition by c.customer_id) as avg_order
from customer c
left join orders o on c.customer_id = o.customer_id
left join order_items oi on o.order_id = oi.order_id
order by total desc, orders_count desc;

-- 5. Найти имена и фамилии клиентов с топ-3 минимальной и топ-3 максимальной суммой транзакций за весь период (учесть клиентов, у которых нет заказов, приняв их сумму транзакций за 0).

(
    select
        c.first_name,
        c.last_name,
        coalesce(sum(oi.item_list_price_at_sale * oi.quantity), 0) as total
    from customer c
    left join orders o on c.customer_id = o.customer_id
    left join order_items oi on o.order_id = oi.order_id
    group by c.customer_id, c.first_name, c.last_name
    order by total desc
    limit 3
)
union all
(
    select
        c.first_name,
        c.last_name,
        coalesce(sum(oi.item_list_price_at_sale * oi.quantity), 0) as total
    from customer c
    left join orders o on c.customer_id = o.customer_id
    left join order_items oi on o.order_id = oi.order_id
    group by c.customer_id, c.first_name, c.last_name
    order by total asc
    limit 3
)
order by total;

-- 6. Вывести только вторые транзакции клиентов (если они есть) с помощью оконных функций. Если у клиента меньше двух транзакций, он не должен попасть в результат.

select
    o.order_id,
    o.customer_id, 
    c.first_name,
    c.last_name,
    o.order_date
from (
    select 
        order_id,
        customer_id,
        order_date,
        row_number() over (partition by customer_id order by order_date) as num
    from orders
) o
join customer c on o.customer_id = c.customer_id
where o.num = 2;

-- 7. Вывести имена, фамилии и профессии клиентов, а также длительность максимального интервала (в днях) между двумя последовательными заказами. Исключить клиентов, у которых только один или меньше заказов.

select
    c.first_name,
    c.last_name,
    c.job_title,
    max(next_date - order_date) as max_interval
from (
    select 
        customer_id,
        order_date,
        lead(order_date) over (partition by customer_id order by order_date) as next_date
    from orders
) o
join customer c on o.customer_id = c.customer_id
where next_date is not null
group by c.customer_id, c.first_name, c.last_name, c.job_title
order by max_interval desc;

-- 8. Найти топ-5 клиентов (по общему доходу) в каждом сегменте благосостояния (wealth_segment). Вывести имя, фамилию, сегмент и общий доход. Если в сегменте менее 5 клиентов, вывести всех.
 
select first_name, last_name, wealth_segment, total
from (
    select 
        c.first_name,
        c.last_name,
        c.wealth_segment,
        coalesce(sum(oi.item_list_price_at_sale * oi.quantity), 0) as total,
        row_number() over (partition by c.wealth_segment order by coalesce(sum(oi.item_list_price_at_sale * oi.quantity), 0) DESC) as rank
    from customer c
    left join orders o on c.customer_id = o.customer_id
    left join order_items oi on o.order_id = oi.order_id
    group by c.customer_id, c.first_name, c.last_name, c.wealth_segment
) t
where rank <= 5
order by wealth_segment, total desc;
 