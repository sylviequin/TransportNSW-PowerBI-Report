CREATE SCHEMA TRANSPORT_NSW;
USE TRANSPORT_NSW; 
# =====================================
# Create table 
CREATE TABLE transport_fares (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year_Month` YEAR,
    Card_Type VARCHAR(20),
    Travel_Mode VARCHAR(20),
    Distance_Band VARCHAR(20),
    Fare_nominal_Peak_time DECIMAL(5,2),
    CPI DECIMAL(6,2),
    Fare_real_Peaktime DECIMAL(5,2),
    weekday_cap DECIMAL(5,2),
    weekly_cap DECIMAL(5,2)
);
CREATE TABLE trip (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` YEAR,
    `Month` VARCHAR(20),
    Travel_Mode VARCHAR(20),
    Card_Type VARCHAR(20),
    Trip float
);
CREATE TABLE satisfaction (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` YEAR,
    Travel_Mode VARCHAR(20),
    Service_Driver VARCHAR(20),
    Service_Attribute VARCHAR(50),
    Metrics VARCHAR(20),
    Customer_Satis_Index FLOAT
);
CREATE TABLE travel_mode_lga (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` INT,
    Hh_lga_id INT,
    Hh_lga_name VARCHAR(100),
    Travel_mode VARCHAR(50),
    Trips_by_mode INT,
    Pct_of_total_trips DECIMAL(5,2),
    Mode_share DECIMAL(5,2),
    Distance_by_mode INT,
    Pct_of_total_distance DECIMAL(5,2),
    Trip_avg_distance DECIMAL(6,2),
    Trip_avg_time DECIMAL(6,2)
);
CREATE TABLE lga (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` INT,
    LGAs VARCHAR(100),
    CBD_distance DECIMAL(6,2),
    `Usage (%)` DECIMAL(6,2)
);
CREATE TABLE peak_hour (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Time` TIME,
    Transport_mode VARCHAR(50),
    Passenger_count INT,
    year INT,
    month VARCHAR(20)
);
CREATE TABLE public_holidays (
    id INT AUTO_INCREMENT PRIMARY KEY,
    holiday_date DATE,
    holiday_name VARCHAR(100)
); 

/* ============================================================
   PART 1 — HOW ARE PEOPLE TRAVELLING?
   ============================================================ */

-- ───────────────────────────────────────────────────────────── 
# Q1 | How many trips were taken each year on each mode?
-- Goals: show the total of number of journey per transport mode per year
-- Key findings: obviously , train is the most common tranport used. Most of mode was falling during Covid 19, train mode most suffer from the covid impact, nearly halving but ligh rail increase.
-- ─────────────────────────────────────────────────────────────

SELECT `Year`,
		Travel_Mode,
		round(sum(Trip)/1000000.0,1)  as total_trips, -- total trip per mode
    CASE
        WHEN year IN (2019, 2020, 2021) THEN 'COVID'
        WHEN year IN (2022, 2023) THEN 'Recovery'
        WHEN year >= 2024         THEN 'Post-COVID'
        ELSE                           'Pre-COVID'
    END 						AS time_period 		-- divided into different period
FROM trip
WHERE Travel_Mode IN ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro') -- exclude rows which hold "unallocated"
GROUP BY Travel_Mode, `Year`
ORDER BY `Year`, total_trips;

-- ───────────────────────────────────────────────────────────── 
# Q2 | Which is the most popular transport mode?
-- Goals: show the list of mode by total trips in 2023, with each mode's share of all transport trips (%)
-- Key findings: Train is dominantly used (over 50%), followed by Bus (~40%). Ferry and Metro seem to be insignificant contributors for transport in NSW. (1)
-- In 2023, Metro is newest and fasting-growing mode since May, 2019 while other starts since 2016
-- ─────────────────────────────────────────────────────────────
select Travel_Mode,	
		round(sum(Trip)/1000000.0,2)  	as total_trips_by_mode,
        round(
			sum(Trip) * 100.0 
				/ (select sum(Trip) -- Subquery to find the total trip by all mode 
					from trip),
            2) 						as `total_trips_per_share (%)`
from trip
where `Year` = 2023
group by Travel_Mode
order by `total_trips_per_share (%)` desc;

-- ─────────────────────────────────────────────────────────────
-- Q3 | Which months are the busiest for public transport?
--
--    Goals: show the Average monthly trips across 2019–2023, then mapping with those months have several holidays in year
--
--    Key finding: March is the busiest month on average (48.9M).
--    January and July are quieter (school holiday effect).
-- ─────────────────────────────────────────────────────────────
		-- Step 1: get total trip per month + year 
select `Year`,
		`Month`,
        sum(Trip) as monthly_trips
from trip 
where Travel_Mode IN ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro')
      and `Year` BETWEEN 2019 AND 2023       -- use balance count trips in the presence of 'Metro'
group by `Year`,`Month`;

		-- step 2: Categories in seasonal patterns
select `Month`,
		round(avg(monthly_trips)/ 1000000.0, 2) as avg_trips,
        max(monthly_trips) 						as max_trips_per_month,
        min(monthly_trips)						as min_trips_per_month,
        case
			when `Month` in ('December','January') then 'Summer-break'
            when `Month` in ('March', 'April')	then 'Autumn-peak'
            when `Month` in ('July') 	then 'Winter-break'
            when `Month` in ('September','October') 	then 'Spring-peak'
            else 							'no special term'
        end 									as seasonal_pattern
from -- copy from step 1
		(select `Year`,
				`Month`,
				sum(Trip) 						as monthly_trips
		from trip 
		where Travel_Mode IN ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro')
			  and `Year` BETWEEN 2019 AND 2023       -- use balance count trips in the presence of 'Metro'
		group by `Year`,`Month`) 				as monthy_data 
group by `Month`
order by avg_trips DESC;

			-- Step 3: double check holiday in public_holiday
select MONTH(STR_TO_DATE(day, '%d/%m/%Y')) AS month,
		count(SIGNIFICANCE) as num_of_holiday
from  public_holiday
group by MONTH(STR_TO_DATE(day, '%d/%m/%Y'));

-- ─────────────────────────────────────────────────────────────
-- Q4 |  How has travel changed since COVID?
--    What it shows: Compares each year's total trips to 2019 (the last full pre-COVID year) so you can see how much of the network has bounced back.
--    Key finding: Metro and Light Rail have grown ABOVE their
--    2019 levels. Trains and buses are still recovering.
-- Using CTE to find the total trip in 2019 and the rest of year. then show the change varies to 2019
-- ─────────────────────────────────────────────────────────────
with -- create two component for fomula
	base_2019 AS (
		select Travel_Mode,
				sum(Trip) as trips_in_2019
		from trip
        where `Year` = 2019
        group by Travel_Mode
        ),
	annual_trip AS (
		select  `Year`,
				Travel_Mode,
				sum(Trip) as annual_trip
		from trip
        group by `Year`, Travel_Mode
        )
select -- compute the recovery gap
	a.`Year`,
    a.Travel_Mode,
    a.annual_trip as annual_trip,
    b.trips_in_2019 as trip_in_2019,
    (a.annual_trip - b.trips_in_2019) as recovery_gap,
    -- notation to see which mode have the sign of recovery from 2019 onward.
    case
		when (a.annual_trip - b.trips_in_2019) = 0 then 'Remaining'
        when (a.annual_trip - b.trips_in_2019) > 0 then 'Recovered'
        else 											'Loss'
    end									as recovery_label
from annual_trip a
join base_2019 b on b.Travel_Mode = a.Travel_Mode
where a.`Year` between 2019 and 2025

order by a.`Year`, a.Travel_Mode;

/* ============================================================
   PART 2 — CUSTOMER SATISFACTION 
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q5 | How does satisfaction compare across Bus, Train, Ferry?
--    What it shows: The overall satisfaction score for each mode, plus which areas passengers praise or criticise.
--    Key finding: Ferry scores highest overall (97%).
--    All modes score well on safety. Train punctuality
--    is by far the weakest score across all modes.
-- ─────────────────────────────────────────────────────────────
select Travel_Mode,
		Service_Driver,
        ROUND(avg(Customer_Satis_Index),2) as avg_satisfaction_point,
        count(*) as no_question_per_driver,
        case
			when avg(Customer_Satis_Index) >= 0.9 then "STRONG"
            when avg(Customer_Satis_Index) >= 0.75 then "ACCEPTABLE"
            when avg(Customer_Satis_Index) >= 0.60 then "WEAK"
            else 										"CRITICAL GAP"
        end										as performance_label
FROM satisfaction 
group by Travel_Mode, Service_Driver 
order by Travel_Mode, avg_satisfaction_point desc;

-- ─────────────────────────────────────────────────────────────
-- Q6 | Which service qualities score highest across all modes?
-- ─────────────────────────────────────────────────────────────
select Service_Driver,
		round(avg(Customer_Satis_Index),2) as avg_satisfaction_point,
        round(max(Customer_Satis_Index),2) as best_mode_score,
		round(min(Customer_Satis_Index),2) as worst_mode_score,
        round(round(max(Customer_Satis_Index),2) - round(min(Customer_Satis_Index),2),2) as score_gap -- gap btw best and worst score
        -- Notation with gap: big gap ~ inconsistent service
from satisfaction
where Service_Driver != 'Overall' -- exclude overrall view
group by Service_Driver
order by avg_satisfaction_point;
        
/* ============================================================
   PART 3 — PAYMENT PATTERN 
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q7 | How many people use each type of Opal card in 2023
--
--    What it shows: Total trips by card category over time, showing the mix of full-fare adult, concession, senior, child, and contactless bank card users.
--
--    Key finding: Adult people are accounted for the most cusomter using public transport
-- 		
-- ─────────────────────────────────────────────────────────────
select  Card_type,
		sum(Trip) as total_trip,
        round(sum(Trip)*100.0 
			/ (Select sum(Trip) from trip),4) as share_pct -- the share of each card type 
from trip
where Travel_Mode in ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro')
group by Card_type
order by share_pct desc;

-- ─────────────────────────────────────────────────────────────
-- Q8 | Are more people tapping on with a bank card? which travel do people prefer to use CTP (2 steps) 
--
--    What it shows: The percentage of each mode using bank contactless payment compared to those using all card type
--
--    **Key finding**: The `CTP` card type turned out to be contactless bank tap-and-go, growing really fast from nearly 0.01% in 2018 and 2017  to 3.2% of total card type used in tfNSW, dominantly becoming the most preferable used card to tap-on-and-off (over 30%) . 
-- 		Over 1 in 3 trips made in 2025 tapped from CTP rather than a registered Opal.
-- 		Ferry took CTP over other registered opal card. 
-- ─────────────────────────────────────────────────────────────
select `Year`,
		Card_type,
		sum(Trip) as total_trip,
        round(sum(Trip)*100.0 
			/ (Select sum(Trip) from trip),4) as share_pct -- the share of each card type 
from trip
where Card_type in ('Adult', 'CTP', 'Senior/ Pensioner', 'Concession', 'School student', 'Child/Youth', 'Employee') and
	 Travel_Mode in ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro')
group by `Year`, Card_type
order by `Year`, share_pct desc;

-- Consider only CTP share per travel mode
select `Year`,
		Travel_Mode,
			-- The percentage of each mode using bank contactless payment
		sum(
			case when Card_type = 'CTP' then Trip else 0 end
				)           				as CTP_trips_per_mode,
			-- The percentage of each mode using all card type
		sum(Trip) 							as all_cardtype_trip_per_mode,
			-- The share of CTP to all card type
		round(sum(
			case when Card_type = 'CTP' then Trip else 0 end
				) / NULLIF(sum(Trip),0),3)  as bank_card_pct
from trip
where Card_type in ('Adult', 'CTP', 'Senior/ Pensioner', 'Concession', 'School student', 'Child/Youth', 'Employee') and
	 Travel_Mode in ('Bus', 'Train', 'Ferry', 'Light Rail', 'Metro')
group by `Year`, Travel_Mode
order by bank_card_pct desc;

/* ============================================================
   PART 4 — HOW THE TRANPORT VARY ACROSS REGION
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q9 | Which areas of Sydney use public transport the most?
--
--    What it shows: PT use % for each Sydney LGA in 2021, ranked from highest to lowest, with a distance label.

--    Key finding: The Greater Sydney and Inner-west suburbs (Burwood, Strathfield) have the highest PT use. Outer areas like Camden and Penrith whose distance are mostly far from Syney CBD rely much more on cars.
--    Inner areas use PT roughly 4× more than outer/regional areas — but some outer areas defy the pattern (see Parramatta and Blacktown).
-- ─────────────────────────────────────────────────────────────
select LGAs, 
		CBD_distance,
		`Usage (%)`,
        case
			when `Usage (%)` >= 0.25 then 'Highly used'
            when `Usage (%)` >= 0.15 then 'Moderately used'
            when `Usage (%)`>= 0.10 then 'Lightly used'
            else						'personal-vehicle-dependent'
        end
from lga
order by CBD_distance, `Usage (%)`;
			
-- ─────────────────────────────────────────────────────────────
-- Q10 | Which LGAs had the biggest change in PT use in 2024?
--
--    What it shows: Compares each LGA's public transport modal share in 2023 vs 2024 — who grew, who shrank. take account for "public transport, excluding *)
--
--    Key finding: Randwick saw the biggest gains. Some outer LGAs dipped slightly.
-- ─────────────────────────────────────────────────────────────
with 
	model_share_2023 as (
		select 	Hh_lga_name,
				avg(Mode_share)				as share_2023
		from travel_mode_lga
        where `Year` = 2023 and Travel_mode in ('public transport')
		group by Hh_lga_name
						),
	model_share_2024 as (
		select 	Hh_lga_name,
				avg(Mode_share)				as share_2024
		from travel_mode_lga
        where `Year` = 2024 and Travel_mode in ('public transport')
        group by Hh_lga_name
						)
select 	m4.Hh_lga_name,
		m3.share_2023,
        m4.share_2024,
        -- The pct change (%)
        round((m4.share_2024 - m3.share_2023)/ m3.share_2023,3) as pct_change,
        case
			when ((m4.share_2024 - m3.share_2023)/ m3.share_2023) >= 0.5 then 'doublely increased'
            when ((m4.share_2024 - m3.share_2023)/ m3.share_2023) < 0 then 'dipping'
            when ((m4.share_2024 - m3.share_2023)/ m3.share_2023) = 0 then 'no change'
            else 															'slightly increased'
        end									as direction
from model_share_2024 					    as m4
join model_share_2023						as m3 
		on m4.Hh_lga_name = m3.Hh_lga_name
order by pct_change;

select distinct(Travel_mode) from travel_mode_lga;

-- ─────────────────────────────────────────────────────────────
-- Q11 | Where do people spend the most time travelling? see if the time travel on average and the distance each trip would take per mode on each LGA could influence on the commuter decision.
--
--    What it shows: Per LGA: total distance travelled, avg trip time, and avg trip distance for EVERY mode — to see whether time and distance influence the choice to use public transport over driving.
--    Key findings:
--      Where PT is FASTER than car (time_penalty < 0):
--        Strathfield (−2.3 min), Sydney (−1.6 min),
--        Burwood (−1.6 min), Canada Bay (−1.3 min),
--        North Sydney (−0.8 min) — all have PT mode share
--        above 13%, confirming that time competitiveness
--        drives PT uptake.
--      Where PT is MUCH SLOWER than car (> 15 min penalty):
--        Wingecarribee (+24.8 min), Shellharbour (+21.2 min),
--        Newcastle (+20.1 min) — all have PT mode share
--        below 8%, confirming the time penalty is a
--        major deterrent to PT choice.
--      Total distance tells a different story: Central Coast
--        has the highest PT total distance (2.1M km) despite
--        a 14-min time penalty — volume driven by necessity,
--        not convenience.
-- ─────────────────────────────────────────────────────────────
-- CTE: pivot all two modes into columns in one table scan
    
WITH mode_pivot AS (
    select
        Hh_lga_name,
 
        -- PUBLIC TRANSPORT
        max(case when Travel_mode = 'public transport'
            THEN Trips_by_mode      END)        AS pt_trip,
        max(case when Travel_mode = 'public transport'
            THEN Distance_by_mode END)       AS total_dist_pt_km,
        max(case when Travel_mode = 'public transport'
            THEN Trip_avg_distance END)      AS avg_dist_pt_km,
        max(case when Travel_mode = 'public transport'
            THEN Trip_avg_time END)        AS avg_time_pt_mins,
        max(case when Travel_mode = 'public transport'
            THEN Mode_share END)                AS pt_mode_share,
 
        -- VEHICLE DRIVER
        max(case when Travel_mode = 'vehicle driver'
            THEN Trips_by_mode      END)        AS car_trip,
        max(case when Travel_mode = 'vehicle driver'
            THEN Distance_by_mode END)       AS total_dist_car_km,
        max(case when Travel_mode = 'vehicle driver'
            THEN Trip_avg_distance END)      AS avg_dist_car_km,
        max(case when Travel_mode = 'vehicle driver'
            THEN Trip_avg_time END)        AS avg_time_car_mins,
        max(case when Travel_mode = 'vehicle driver'
            THEN Mode_share END)                AS car_mode_share
	from travel_mode_lga
    where `year`         = 2024
	and Travel_mode IN ('public transport', 'vehicle driver')
    group by Hh_lga_name 
		) 
select
    Hh_lga_name,
     -- ── PUBLIC TRANSPORT
    avg_dist_pt_km,
    avg_time_pt_mins,
    pt_mode_share,
    ROUND(avg_dist_pt_km
          / NULLIF(avg_time_pt_mins / 60.0, 0), 1)      as pt_speed_kmh,
    -- ── VEHICLE (DRIVER)
    total_dist_car_km,
    avg_dist_car_km,
    avg_time_car_mins,
    car_mode_share,
    ROUND(avg_dist_car_km
          / NULLIF(avg_time_car_mins / 60.0, 0), 1)     as car_speed_kmh,
	
    -- ── Computing METRICS ────────────────────────────────
    -- Extra mins PT takes vs driving. Negative = PT is faster.
    ROUND(avg_time_pt_mins - avg_time_car_mins, 1)      as time_penalty_mins,
    -- Extra km PT travels vs car (detour factor)
    ROUND(avg_dist_pt_km - avg_dist_car_km, 1)          as dist_diff_km,
    case -- compare time and decision (10 mins considerable
		when avg_time_pt_mins - avg_time_car_mins < 0 then 'pt faster'
        when avg_time_pt_mins - avg_time_car_mins >= 10
			and pt_mode_share > 10 then 'pt later 10 mins - still choose pt'
		when avg_time_pt_mins - avg_time_car_mins > 15 
			and pt_mode_share < 8 then 'car prefer'
		when avg_time_pt_mins - avg_time_car_mins > 10 then 'noticeable gap - pt not preferred'
        else												'unnotice'
    end
from mode_pivot
order by time_penalty_mins DESC;
    
----------
-- Q12 | Where do people spend the most time travelling —
--       and what does a trip cost them?
--
--    Key finding: Wollondilly residents spend 47 minutes per
--    average PT trip — the longest in the dataset — while
--    paying the same fare cap as someone in North Sydney who
--    travels just 16 minutes. Long-distance commuters get
--    relatively poor value for time spent, but get closer to CBD, the shorter distance for the same amount of money spent.
-- ─────────────────────────────────────────────────────────────
select
    Hh_lga_name,
    Trip_avg_time           AS avg_trip_mins,
    Trip_avg_distance       AS avg_dist_km,
    fa.avg_fare_all_modes   AS avg_fare_2024,
    fa.daily_cap
from  travel_mode_lga lga
inner join (
			-- Average fare and daily cap across all modes in 2024
			select
				avg(Fare_nominal_Peak_time) as avg_fare_all_modes,
				max(weekday_cap) 						as daily_cap,
				`Year_Month`
			from transport_fares
			where `Year_Month` = 2024
			group by `Year_Month`
					) 	as fa
on fa.`Year_Month` = lga.`Year` 
where lga.`Year`        = 2024
	and lga.Travel_mode in ('public transport','public transport*', 'public transport**')
order by avg_trip_mins desc;

/* ============================================================
   PART 5 — IS PUBLIC TRANSPORT AFFORDABLE?
   ============================================================ */
   
-- ─────────────────────────────────────────────────────────────
-- Q13 | What does a typical trip cost? How many trips does it take before hitting a daily cap or week cap per per travel mode and for which distance
-- Key findings: Train cost even short trip or long trip seems to be more expensive than other
-- ─────────────────────────────────────────────────────────────
select  
		Travel_Mode,
		Distance_Band,
        Fare_nominal_Peak_time as nominal_fare,
        Fare_real_Peaktime     as real_fare_2021,
        -- How many trip before hitting daily cap
        floor(weekday_cap/Fare_nominal_Peak_time) as no_of_trip_per_day,
        floor(weekly_cap/Fare_nominal_Peak_time) as no_of_trip_per_week
from transport_fares
where `Year_Month` = 2024
order by no_of_trip_per_day;

-- ─────────────────────────────────────────────────────────────
-- Q14 | Which mode gives the best value for short trips
		-- 		Compares the cheapest fare on each mode in 2024, and how it compares to the daily cap — so you
		--    	can see which mode stretches your money the furthest for a quick local trip.
-- Key findings: Bus and light rail is the cheapeast short trip at $3.2. Ferry is the most expensive ones. 
-- ─────────────────────────────────────────────────────────────
select 	Travel_Mode,
		min(Fare_nominal_Peak_time) as cheapeast_fare,
        min(Distance_Band) 			as distance_covered,
        max(weekday_cap) 			as daily_cap,
        floor(max(weekday_cap)) / min(Fare_nominal_Peak_time) as short_trips_before_cap
from transport_fares
where `Year_Month` = 2024
group by Travel_Mode 
order by cheapeast_fare; 


