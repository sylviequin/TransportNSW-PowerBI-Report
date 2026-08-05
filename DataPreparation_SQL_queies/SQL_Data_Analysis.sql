CREATE SCHEMA TRANSPORT_NSW;
USE TRANSPORT_NSW; 
# =====================================
# Create table 
CREATE TABLE transport_fares (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year_MONth` YEAR,
    Card_Type VARCHAR(20),
    Travel_Mode VARCHAR(20),
    Distance_BAND VARCHAR(20),
    Fare_noMINal_Peak_time DECIMAL(5,2),
    CPI DECIMAL(6,2),
    Fare_real_Peaktime DECIMAL(5,2),
    weekday_cap DECIMAL(5,2),
    weekly_cap DECIMAL(5,2)
);
CREATE TABLE trip (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` YEAR,
    `MONth` VARCHAR(20),
    Travel_Mode VARCHAR(20),
    Card_Type VARCHAR(20),
    Trip float
);
CREATE TABLE satisfactiON (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` YEAR,
    Travel_Mode VARCHAR(20),
    Service_Driver VARCHAR(20),
    Service_Attribute VARCHAR(50),
    Metrics VARCHAR(20),
    Customer_Satis_INdex FLOAT
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
    Trip_AVG_distance DECIMAL(6,2),
    Trip_AVG_time DECIMAL(6,2)
);
CREATE TABLE lga (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Year` INT,
    LGAS VARCHAR(100),
    CBD_distance DECIMAL(6,2),
    `Usage (%)` DECIMAL(6,2)
);
CREATE TABLE peak_hour (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Time` TIME,
    Transport_mode VARCHAR(50),
    PASsenger_count INT,
    year INT,
    mONth VARCHAR(20)
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
# Q1 | How many trips were taken each year ON each mode?
		-- Goals: show the total of number of journey per transport mode per year
-- ─────────────────────────────────────────────────────────────
SELECT `Year`,
		Travel_Mode,
		ROUND(SUM(Trip)/1000000.0,1)  	AS total_trips, -- total trip per mode
    CASE
        WHEN year IN (2019, 2020, 2021) THEN 'COVID'
        WHEN year IN (2022, 2023) 		THEN 'Recovery'
        WHEN year >= 2024         		THEN 'Post-COVID'
        ELSE                           'Pre-COVID'
    END 								AS time_period 		-- divided INto different period
FROM trip
WHERE Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro') -- exclude rows which hold "unallocated"
GROUP BY Travel_Mode, `Year`
ORDER BY `Year`, total_trips;
-- ───────────────────────────────────────────────────────────── 
-- Key fINdINgs: 
		-- obviously , traIN is the most commONly-used tranport mode. 
		-- Most of mode wAS fallINg durINg Covid 19, traIN mode is the most driver sufferred FROM the covid impact, nearly halvINg WHEREAS ligh rail mode INcreASed.
		-- State that due to Covid impact, residents/ people prefer stayINg at home or havINg short-distanced trips WITHIN lightrail 
-- ─────────────────────────────────────────────────────────────

-- ───────────────────────────────────────────────────────────── 
# Q2 | Which is the most popular transport mode?
-- Goals: show the list of mode by total trips IN 2023, WITH each mode's share of all transport trips (%)
-- ─────────────────────────────────────────────────────────────
SELECT Travel_Mode,	
		ROUND(SUM(Trip)/1000000.0,2)  	AS  total_trips_by_mode,
        ROUND(
			SUM(Trip) * 100.0 
				/ (SELECT SUM(Trip) -- Subquery to fINd the total trip by all mode 
					FROM trip),
            2) 					     	AS `total_trips_per_share (%)`
FROM trip
WHERE `Year` = 2023
GROUP BY Travel_Mode
ORDER BY `total_trips_per_share (%)` DESC;
-- ───────────────────────────────────────────────────────────── 
-- Key fINdINgs: 
		-- TraIN is doMINantly used (over 50%), followed by Bus (~40%). 
		-- Ferry AND Metro seem to be INsignificant cONtributors for transport IN NSW FROM 2016-2025. (1)
		-- IN 2023, Metro is newest AND fAStINg-growINg mode s(Metro INitiatives impplemented IN 2019) while other starts sINce 2016
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Q3 | Which mONths are the busiest for public transport?
--
--    Goals: show the Average mONthly trips across 2019–2023, THEN mappINg WITH those mONths have several holidays IN year
--
--    Key fINdINg: March is the busiest mONth ON average (48.9M).
--    January AND July are quieter (school holiday effect).
-- ─────────────────────────────────────────────────────────────
		-- Step 1: get total trip per mONth + year 
SELECT `Year`,
		`MONth`,
        SUM(Trip) AS mONthly_trips
FROM trip 
WHERE Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro')
      AND `Year` BETWEEN 2019 AND 2023       -- use balance count trips IN the presence of 'Metro'
GROUP BY `Year`,`MONth`;

		-- step 2: Categories IN seASONal patterns
SELECT `MONth`,
		ROUND(AVG(mONthly_trips)/ 1000000.0, 2) AS AVG_trips,
        MAX(mONthly_trips) 						AS MAX_trips_per_mONth,
        MIN(mONthly_trips)						AS MIN_trips_per_mONth,
        CASE
			WHEN `MONth` IN ('December','January') THEN 'SUMmer-break'
            WHEN `MONth` IN ('March', 'April')	THEN 'Autumn-peak'
            WHEN `MONth` IN ('July') 	THEN 'WINter-break'
            WHEN `MONth` IN ('September','October') 	THEN 'SprINg-peak'
            ELSE 							'no special term'
        END 									AS seASONal_pattern
FROM -- copy FROM step 1
		(SELECT `Year`,
				`MONth`,
				SUM(Trip) 						AS mONthly_trips
		FROM trip 
		WHERE Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro')
			  AND `Year` BETWEEN 2019 AND 2023       -- use balance count trips IN the presence of 'Metro'
		GROUP BY `Year`,`MONth`) 				AS mONthy_data 
GROUP BY `MONth`
ORDER BY AVG_trips DESC;

			-- Step 3: double check holiday IN public_holiday
SELECT MONTH(STR_TO_DATE(day, '%d/%m/%Y')) AS mONth,
		count(SIGNIFICANCE) AS num_of_holiday
FROM  public_holiday
GROUP BY MONTH(STR_TO_DATE(day, '%d/%m/%Y'));

-- ─────────────────────────────────────────────────────────────
-- Q4 |  How hAS travel changed sINce COVID?
--    What it shows: Compares each year's total trips to 2019 (the lASt full pre-COVID year) so you can see how much of the network hAS bounced back.
--    Key fINdINg: Metro AND Light Rail have grown ABOVE their
--    2019 levels. TraINs AND buses are still recoverINg.
-- UsINg CTE to fINd the total trip IN 2019 AND the rest of year. THEN show the change varies to 2019
-- ─────────────────────────────────────────────────────────────
WITH -- create two compONent for fomula
	bASe_2019 AS (
		SELECT Travel_Mode,
				SUM(Trip) AS trips_IN_2019
		FROM trip
        WHERE `Year` = 2019
        GROUP BY Travel_Mode
        ),
	annual_trip AS (
		SELECT  `Year`,
				Travel_Mode,
				SUM(Trip) AS annual_trip
		FROM trip
        GROUP BY `Year`, Travel_Mode
        )
SELECT -- compute the recovery gap
	a.`Year`,
    a.Travel_Mode,
    a.annual_trip AS annual_trip,
    b.trips_IN_2019 AS trip_IN_2019,
    (a.annual_trip - b.trips_IN_2019) AS recovery_gap,
    -- notatiON to see which mode have the sign of recovery FROM 2019 ONward.
    CASE
		WHEN (a.annual_trip - b.trips_IN_2019) = 0 THEN 'RemaININg'
        WHEN (a.annual_trip - b.trips_IN_2019) > 0 THEN 'Recovered'
        ELSE 											'Loss'
    END									AS recovery_label
FROM annual_trip a
JOIN bASe_2019 b ON b.Travel_Mode = a.Travel_Mode
WHERE a.`Year` between 2019 AND 2025

ORDER BY a.`Year`, a.Travel_Mode;

/* ============================================================
   PART 2 — CUSTOMER SATISFACTION 
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q5 | How does satisfactiON compare across Bus, TraIN, Ferry?
--    What it shows: The overall satisfactiON score for each mode, plus which areAS pASsengers praise or criticise.
--    Key fINdINg: Ferry scores highest overall (97%).
--    All modes score well ON safety. TraIN punctuality
--    is by far the weakest score across all modes.
-- ─────────────────────────────────────────────────────────────
SELECT Travel_Mode,
		Service_Driver,
        ROUND(AVG(Customer_Satis_INdex),2) AS AVG_satisfactiON_poINt,
        count(*) AS no_questiON_per_driver,
        CASE
			WHEN AVG(Customer_Satis_INdex) >= 0.9 THEN "STRONG"
            WHEN AVG(Customer_Satis_INdex) >= 0.75 THEN "ACCEPTABLE"
            WHEN AVG(Customer_Satis_INdex) >= 0.60 THEN "WEAK"
            ELSE 										"CRITICAL GAP"
        END										AS performance_label
FROM satisfactiON 
GROUP BY Travel_Mode, Service_Driver 
ORDER BY Travel_Mode, AVG_satisfactiON_poINt DESC;

-- ─────────────────────────────────────────────────────────────
-- Q6 | Which service qualities score highest across all modes?
-- ─────────────────────────────────────────────────────────────
SELECT Service_Driver,
		ROUND(AVG(Customer_Satis_INdex),2) AS AVG_satisfactiON_poINt,
        ROUND(MAX(Customer_Satis_INdex),2) AS best_mode_score,
		ROUND(MIN(Customer_Satis_INdex),2) AS worst_mode_score,
        ROUND(ROUND(MAX(Customer_Satis_INdex),2) - ROUND(MIN(Customer_Satis_INdex),2),2) AS score_gap -- gap btw best AND worst score
        -- NotatiON WITH gap: big gap ~ INcONsistent service
FROM satisfactiON
WHERE Service_Driver != 'Overall' -- exclude overrall view
GROUP BY Service_Driver
ORDER BY AVG_satisfactiON_poINt;
        
/* ============================================================
   PART 3 — PAYMENT PATTERN 
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q7 | How many people use each type of Opal card IN 2023
--    What it shows: Total trips by card category over time, showINg the mix of full-fare adult, cONcessiON, senior, child, AND cONtactless bank card users.
--    Key fINdINg: Adult people are accounted for the most cusomter usINg public transport	
-- ─────────────────────────────────────────────────────────────
SELECT  Card_type,
		SUM(Trip) 								AS total_trip,
        ROUND(SUM(Trip)*100.0 
			/ (SELECT SUM(Trip) FROM trip),4) 	AS share_pct -- the share of each card type 
FROM trip
WHERE Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro')
GROUP BY Card_type
ORDER BY share_pct DESC;

-- ─────────────────────────────────────────────────────────────
-- Q8 | Are more people tappINg ON WITH a bank card? which travel do people prefer to use CTP (2 steps) 
--    What it shows: The percentage of each mode usINg bank cONtactless payment compared to those usINg all card type
--    **Key fINdINg**: The `CTP` card type turned out to be cONtactless bank tap-AND-go, growINg really fASt FROM nearly 0.01% IN 2018 AND 2017  to 3.2% of total card type used IN tfNSW, doMINantly becoMINg the most preferable used card to tap-ON-AND-off (over 30%) . 
-- 		Over 1 IN 3 trips made IN 2025 tapped FROM CTP rather than a registered Opal.
-- 		Ferry took CTP over other registered opal card. 
-- ─────────────────────────────────────────────────────────────
SELECT `Year`,
		Card_type,
		SUM(Trip) AS total_trip,
        ROUND(SUM(Trip)*100.0 
			/ (SELECT SUM(Trip) FROM trip),4) AS share_pct -- the share of each card type 
FROM trip
WHERE Card_type IN ('Adult', 'CTP', 'Senior/ PensiONer', 'CONcessiON', 'School student', 'Child/Youth', 'Employee') AND
	 Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro')
GROUP BY `Year`, Card_type
ORDER BY `Year`, share_pct DESC;

-- CONsider ONly CTP share per travel mode
SELECT `Year`,
		Travel_Mode,
			-- The percentage of each mode usINg bank cONtactless payment
		SUM(
			CASE WHEN Card_type = 'CTP' THEN Trip ELSE 0 END
				)           				AS CTP_trips_per_mode,
			-- The percentage of each mode usINg all card type
		SUM(Trip) 							AS all_cardtype_trip_per_mode,
			-- The share of CTP to all card type
		ROUND(SUM(
			CASE WHEN Card_type = 'CTP' THEN Trip ELSE 0 END
				) / NULLIF(SUM(Trip),0),3)  AS bank_card_pct
FROM trip
WHERE Card_type IN ('Adult', 'CTP', 'Senior/ PensiONer', 'CONcessiON', 'School student', 'Child/Youth', 'Employee') AND
	 Travel_Mode IN ('Bus', 'TraIN', 'Ferry', 'Light Rail', 'Metro')
GROUP BY `Year`, Travel_Mode
ORDER BY bank_card_pct DESC;

/* ============================================================
   PART 4 — HOW THE TRANPORT VARY ACROSS REGION
   ============================================================ */
-- ─────────────────────────────────────────────────────────────
-- Q9 | Which areAS of Sydney use public transport the most?
--    What it shows: PT use % for each Sydney LGA IN 2021, ranked FROM highest to lowest, WITH a distance label.
--    Key fINdINg: The Greater Sydney AND INner-west suburbs (Burwood, Strathfield) have the highest PT use. Outer areAS like Camden AND Penrith whose distance are mostly far FROM Syney CBD rely much more ON cars.
--    INner areAS use PT roughly 4× more than outer/regiONal areAS — but some outer areAS defy the pattern (see Parramatta AND Blacktown).
-- ─────────────────────────────────────────────────────────────
SELECT LGAS, 
		CBD_distance,
		`Usage (%)`,
        CASE
			WHEN `Usage (%)` >= 0.25 THEN 'Highly used'
            WHEN `Usage (%)` >= 0.15 THEN 'Moderately used'
            WHEN `Usage (%)`>= 0.10 THEN 'Lightly used'
            ELSE						'persONal-vehicle-depENDent'
        END
FROM lga
ORDER BY CBD_distance, `Usage (%)`;
			
-- ─────────────────────────────────────────────────────────────
-- Q10 | Which LGAS had the biggest change IN PT use IN 2024?
--    What it shows: Compares each LGA's public transport modal share IN 2023 vs 2024 — who grew, who shrank. take account for "public transport, excludINg *)
--    Key fINdINg: RANDwick saw the biggest gaINs. Some outer LGAS dipped slightly.
-- ─────────────────────────────────────────────────────────────
WITH 
	model_share_2023 AS (
		SELECT 	Hh_lga_name,
				AVG(Mode_share)				AS share_2023
		FROM travel_mode_lga
        WHERE `Year` = 2023 AND Travel_mode IN ('public transport')
		GROUP BY Hh_lga_name
						),
	model_share_2024 AS (
		SELECT 	Hh_lga_name,
				AVG(Mode_share)				AS share_2024
		FROM travel_mode_lga
        WHERE `Year` = 2024 AND Travel_mode IN ('public transport')
        GROUP BY Hh_lga_name
						)
SELECT 	m4.Hh_lga_name,
		m3.share_2023,
        m4.share_2024,
        -- The pct change (%)
        ROUND((m4.share_2024 - m3.share_2023)/ m3.share_2023,3) AS pct_change,
        CASE
			WHEN ((m4.share_2024 - m3.share_2023)/ m3.share_2023) >= 0.5 THEN 'doublely INcreASed'
            WHEN ((m4.share_2024 - m3.share_2023)/ m3.share_2023) < 0 THEN 'dippINg'
            WHEN ((m4.share_2024 - m3.share_2023)/ m3.share_2023) = 0 THEN 'no change'
            ELSE 															'slightly INcreASed'
        END									AS directiON
FROM model_share_2024 					    AS m4
JOIN model_share_2023						AS m3 
		ON m4.Hh_lga_name = m3.Hh_lga_name
ORDER BY pct_change;

SELECT distINct(Travel_mode) FROM travel_mode_lga;

-- ─────────────────────────────────────────────────────────────
-- Q11 | WHERE do people spEND the most time travellINg? see if the time travel ON average AND the distance each trip would take per mode ON each LGA could INfluence ON the commuter decisiON.
--    What it shows: Per LGA: total distance travelled, AVG trip time, AND AVG trip distance for EVERY mode — to see whether time AND distance INfluence the choice to use public transport over drivINg.
--    Key findings:
--      WHERE PT is FASTER than car (time_penalty < 0):
--        Strathfield (−2.3 MIN), Sydney (−1.6 MIN),
--        Burwood (−1.6 MIN), Canada Bay (−1.3 MIN),
--        North Sydney (−0.8 MIN) — all have PT mode share above 13%, cONfirMINg that time competitivenes drives PT uptake.
--      WHERE PT is MUCH SLOWER than car (> 15 MIN penalty):
--        WINgecarribee (+24.8 MIN), Shellharbour (+21.2 MIN),
--        NewcAStle (+20.1 MIN) — all have PT mode share below 8%, cONfirMINg the time penalty is a  major deterrent to PT choice.
--      Total distance tells a different story: Central Coast has the highest PT total distance (2.1M km) despite a 14-MIN time penalty — volume driven by necessity,not convenience.
-- ─────────────────────────────────────────────────────────────
WITH mode_pivot AS (
    SELECT
        Hh_lga_name,
        -- PUBLIC TRANSPORT
        MAX(CASE WHEN Travel_mode = 'public transport'
            THEN Trips_by_mode      END)        AS pt_trip,
        MAX(CASE WHEN Travel_mode = 'public transport'
            THEN Distance_by_mode END)       AS total_dist_pt_km,
        MAX(CASE WHEN Travel_mode = 'public transport'
            THEN Trip_AVG_distance END)      AS AVG_dist_pt_km,
        MAX(CASE WHEN Travel_mode = 'public transport'
            THEN Trip_AVG_time END)        AS AVG_time_pt_MINs,
        MAX(CASE WHEN Travel_mode = 'public transport'
            THEN Mode_share END)                AS pt_mode_share,
 
        -- VEHICLE DRIVER
        MAX(CASE WHEN Travel_mode = 'vehicle driver'
            THEN Trips_by_mode      END)        AS car_trip,
        MAX(CASE WHEN Travel_mode = 'vehicle driver'
            THEN Distance_by_mode END)       AS total_dist_car_km,
        MAX(CASE WHEN Travel_mode = 'vehicle driver'
            THEN Trip_AVG_distance END)      AS AVG_dist_car_km,
        MAX(CASE WHEN Travel_mode = 'vehicle driver'
            THEN Trip_AVG_time END)        AS AVG_time_car_MINs,
        MAX(CASE WHEN Travel_mode = 'vehicle driver'
            THEN Mode_share END)                AS car_mode_share
	FROM travel_mode_lga
    WHERE `year`         = 2024
	AND Travel_mode IN ('public transport', 'vehicle driver')
    GROUP BY Hh_lga_name 
		) 
SELECT
    Hh_lga_name,
     -- ── PUBLIC TRANSPORT
    AVG_dist_pt_km,
    AVG_time_pt_MINs,
    pt_mode_share,
    ROUND(AVG_dist_pt_km
          / NULLIF(AVG_time_pt_MINs / 60.0, 0), 1)      AS pt_speed_kmh,
    -- ── VEHICLE (DRIVER)
    total_dist_car_km,
    AVG_dist_car_km,
    AVG_time_car_MINs,
    car_mode_share,
    ROUND(AVG_dist_car_km
          / NULLIF(AVG_time_car_MINs / 60.0, 0), 1)     AS car_speed_kmh,
	
    -- ── ComputINg METRICS ────────────────────────────────
    -- Extra MINs PT takes vs drivINg. Negative = PT is fASter.
    ROUND(AVG_time_pt_MINs - AVG_time_car_MINs, 1)      AS time_penalty_MINs,
    -- Extra km PT travels vs car (detour factor)
    ROUND(AVG_dist_pt_km - AVG_dist_car_km, 1)          AS dist_diff_km,
    CASE -- compare time AND decisiON (10 MINs cONsiderable
		WHEN AVG_time_pt_MINs - AVG_time_car_MINs < 0 THEN 'pt fASter'
        WHEN AVG_time_pt_MINs - AVG_time_car_MINs >= 10
			AND pt_mode_share > 10 THEN 'pt later 10 MINs - still choose pt'
		WHEN AVG_time_pt_MINs - AVG_time_car_MINs > 15 
			AND pt_mode_share < 8 THEN 'car prefer'
		WHEN AVG_time_pt_MINs - AVG_time_car_MINs > 10 THEN 'noticeable gap - pt not preferred'
        ELSE												'unnotice'
    END
FROM mode_pivot
ORDER BY time_penalty_MINs DESC;
    
----------
-- Q12 | WHERE do people spEND the most time travellINg —
--       AND what does a trip cost them?
--
--    Key fINdINg: WollONdilly residents spEND 47 MINutes per
--    average PT trip — the lONgest IN the datASet — while
--    payINg the same fare cap AS someONe IN North Sydney who
--    travels just 16 MINutes. LONg-distance commuters get
--    relatively poor value for time spent, but get closer to CBD, the shorter distance for the same amount of mONey spent.
-- ─────────────────────────────────────────────────────────────
SELECT
    Hh_lga_name,
    Trip_AVG_time           AS AVG_trip_MINs,
    Trip_AVG_distance       AS AVG_dist_km,
    fa.AVG_fare_all_modes   AS AVG_fare_2024,
    fa.daily_cap
FROM  travel_mode_lga lga
INner JOIN (
			-- Average fare AND daily cap across all modes IN 2024
			SELECT
				AVG(Fare_noMINal_Peak_time) AS AVG_fare_all_modes,
				MAX(weekday_cap) 						AS daily_cap,
				`Year_MONth`
			FROM transport_fares
			WHERE `Year_MONth` = 2024
			GROUP BY `Year_MONth`
					) 	AS fa
ON fa.`Year_MONth` = lga.`Year` 
WHERE lga.`Year`        = 2024
	AND lga.Travel_mode IN ('public transport','public transport*', 'public transport**')
ORDER BY AVG_trip_MINs DESC;

/* ============================================================
   PART 5 — IS PUBLIC TRANSPORT AFFORDABLE?
   ============================================================ */
   
-- ─────────────────────────────────────────────────────────────
-- Q13 | What does a typical trip cost? How many trips does it take before hittINg a daily cap or week cap per per travel mode AND for which distance
-- Key fINdINgs: TraIN cost even short trip or lONg trip seems to be more expensive than other
-- ─────────────────────────────────────────────────────────────
SELECT  
		Travel_Mode,
		Distance_BAND,
        Fare_noMINal_Peak_time AS noMINal_fare,
        Fare_real_Peaktime     AS real_fare_2021,
        -- How many trip before hittINg daily cap
        floor(weekday_cap/Fare_noMINal_Peak_time) AS no_of_trip_per_day,
        floor(weekly_cap/Fare_noMINal_Peak_time) AS no_of_trip_per_week
FROM transport_fares
WHERE `Year_MONth` = 2024
ORDER BY no_of_trip_per_day;

-- ─────────────────────────────────────────────────────────────
-- Q14 | Which mode gives the best value for short trips
		-- 		Compares the cheapest fare ON each mode IN 2024, AND how it compares to the daily cap — so you
		--    	can see which mode stretches your mONey the furthest for a quick local trip.
-- Key fINdINgs: Bus AND light rail is the cheapeASt short trip at $3.2. Ferry is the most expensive ONes. 
-- ─────────────────────────────────────────────────────────────
SELECT 	Travel_Mode,
		MIN(Fare_noMINal_Peak_time) AS cheapeASt_fare,
        MIN(Distance_BAND) 			AS distance_covered,
        MAX(weekday_cap) 			AS daily_cap,
        floor(MAX(weekday_cap)) / MIN(Fare_noMINal_Peak_time) AS short_trips_before_cap
FROM transport_fares
WHERE `Year_MONth` = 2024
GROUP BY Travel_Mode 
ORDER BY cheapeASt_fare; 


