-- security metrics v2.4

-- operators to be listed ("valid")
drop table if exists va;
create table va(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	country CHAR(32) NOT NULL,
	network CHAR(32) NOT NULL,
	oldest DATE NOT NULL,
	latest DATE NOT NULL,
	cipher TINYINT UNSIGNED NOT NULL
);

-- operator risk, main score (level 1)
drop table if exists risk_category;
create table risk_category(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	intercept FLOAT(1),
	impersonation FLOAT(1),
	tracking FLOAT(1)
);

-- operator risk, intercept sub-score (level 2)
drop table if exists risk_intercept;
create table risk_intercept(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	voice FLOAT(1),
	sms FLOAT(1)
);

-- operator risk, impersonation sub-score (level 2)
drop table if exists risk_impersonation;
create table risk_impersonation(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	make_calls FLOAT(1),
	recv_calls FLOAT(1)
);

-- operator risk, tracking  sub-score (level 2)
drop table if exists risk_tracking;
create table risk_tracking(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	local_track FLOAT(1),
	global_track FLOAT(1)
);

-- operator risk, attack components (level 3)
drop table if exists attack_component;
create table attack_component(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	realtime_crack FLOAT(1),
	offline_crack FLOAT(1),
	key_reuse_mt FLOAT(1),
	key_reuse_mo FLOAT(1),
	track_tmsi FLOAT(1),
	hlr_inf FLOAT(1),
	freq_predict FLOAT(1),
	PRIMARY KEY (mcc,mnc,lac,month)
);

drop table if exists attack_component_x4;
create table attack_component_x4(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	cipher SMALLINT UNSIGNED,
	call_perc FLOAT(1),
	sms_perc FLOAT(1),
	loc_perc FLOAT(1),
	realtime_crack FLOAT(1),
	offline_crack FLOAT(1),
	key_reuse_mt FLOAT(1),
	key_reuse_mo FLOAT(1),
	track_tmsi FLOAT(1),
	hlr_inf FLOAT(1),
	freq_predict FLOAT(1),
	PRIMARY KEY (mcc,mnc,lac,month,cipher)
);

-- operator security metrics (level 4)
drop table if exists sec_params;
create table sec_params(
	mcc SMALLINT UNSIGNED NOT NULL,
	mnc SMALLINT UNSIGNED NOT NULL,
	country CHAR(32) NOT NULL,
	network CHAR(32) NOT NULL,
	lac SMALLINT UNSIGNED NOT NULL,
	month CHAR(7) NOT NULL,
	cipher SMALLINT UNSIGNED NOT NULL,
	call_count INTEGER UNSIGNED,
	call_mo_count INTEGER UNSIGNED,
	sms_count INTEGER UNSIGNED,
	sms_mo_count INTEGER UNSIGNED,
	loc_count INTEGER UNSIGNED,
	call_success REAL,
	sms_success REAL,
	loc_success REAL,
	call_null_rand REAL,
	sms_null_rand REAL,
	loc_null_rand REAL,
	call_si_rand REAL,
	sms_si_rand REAL,
	loc_si_rand REAL,
	call_nulls REAL,
	sms_nulls REAL,
	loc_nulls REAL,
	call_pred REAL,
	sms_pred REAL,
	loc_pred REAL,
	call_imeisv REAL,
	sms_imeisv REAL,
	loc_imeisv REAL,
	pag_auth_mt REAL,
	call_auth_mo REAL,
	sms_auth_mo REAL,
	loc_auth_mo REAL,
	call_tmsi REAL,
	sms_tmsi REAL,
	loc_tmsi REAL,
	call_imsi REAL,
	sms_imsi REAL,
	loc_imsi REAL,
	ma_len REAL,
	var_len REAL,
	var_hsn REAL,
	var_maio REAL,
	var_ts REAL,
	rand_imsi REAL,
	home_routing REAL,
	PRIMARY KEY (mcc,mnc,lac,month,cipher)
);
	
-- operator hlr query information (level 4+)
-- !! manually populated !!

-- create table hlr_info(
--	mcc SMALLINT UNSIGNED NOT NULL,
--	mnc SMALLINT UNSIGNED NOT NULL,
--	rand_imsi BOOLEAN,
--	home_routing BOOLEAN
-- );

----

drop view if exists n_src;
create view n_src as select * from mnc;

drop view if exists c_src;
create view c_src as select * from mcc;

-- "va" population
delete from va;

insert into va
 select session_info.mcc     as mcc,
	session_info.mnc     as mnc,
	c_src.name           as country,
	n_src.name           as network,
	date(min(timestamp)) as oldest,
	date(max(timestamp)) as latest,
	0                    as cipher
 from session_info, n_src, c_src
 where c_src.mcc = n_src.mcc and n_src.mcc = session_info.mcc and n_src.mnc = session_info.mnc
 and ((t_locupd and (lu_acc or cipher > 1)) or
      (t_sms and (t_release or cipher > 1)) or
      (t_call and (assign or cipher > 1)))
 and (cipher > 0 or duration > 350) and rat = 0
 group by session_info.mcc, session_info.mnc
 order by session_info.mcc, session_info.mnc;

delete from va
 where mcc >= 1000 or mnc >= 1000
 or (mcc = 262 and mnc = 10)
 or (mcc = 262 and mnc = 42)
 or (mcc = 204 and mnc = 21)
 or (mcc = 222 and mnc = 30)
 or (mcc = 228 and mnc = 6)
 or (mcc = 244 and mnc = 17)
 or (mcc = 208 and mnc = 14)
 or (mcc = 901);

insert into va select distinct mcc,mnc,country,network,oldest,latest,1 from va;
insert into va select distinct mcc,mnc,country,network,oldest,latest,2 from va;
insert into va select distinct mcc,mnc,country,network,oldest,latest,3 from va;

--

drop view if exists call_avg;
create view call_avg as
  select mcc, mnc, lac, date_format(timestamp, "%Y-%m") as month, cipher,
	 count(*) as count,
	 sum(CASE WHEN mobile_orig THEN 1 ELSE 0 END) as mo_count,
	 avg(cracked) as success,
	 avg(CASE WHEN enc_null THEN enc_null_rand / enc_null ELSE NULL END) as rand_null_perc,
	 avg(CASE WHEN enc_si   THEN enc_si_rand   / enc_si   ELSE NULL END) as rand_si_perc,
	 avg(enc_null - enc_null_rand) as nulls,
	 avg(predict) as pred,
	 avg(cmc_imeisv) as imeisv,
         -- FIXME: This calculates average of different authentication algorithms (none=0, GSM A3/A3=1, UMTS AKA=2).
         --        Does this make sense?
	 avg(CASE WHEN mobile_term THEN auth ELSE NULL END) as auth_mt,
	 avg(CASE WHEN mobile_orig THEN auth ELSE NULL END) as auth_mo,
	 avg(t_tmsi_realloc) as tmsi,
	 avg(iden_imsi_bc) as imsi
  from session_info
  where rat = 0 and ((t_call or (mobile_term and t_sms = 0)) and
	(call_presence or (cipher=1 and cracked=0) or cipher>1)) and
	(cipher > 0 or duration > 350)
  group by mcc, mnc, lac, month, cipher
  order by mcc, mnc, lac, month, cipher;

-- FIXME: How about A5/2 - this could also be cracked...
-- FIXME: Why longer than 350ms or ciphered?

drop view if exists sms_avg;
create view sms_avg as
  select mcc, mnc, lac, date_format(timestamp, "%Y-%m") as month, cipher,
	 count(*) as count,
	 sum(CASE WHEN mobile_orig THEN 1 ELSE 0 END) as mo_count,
	 avg(cracked) as success,
	 avg(CASE WHEN enc_null THEN enc_null_rand / enc_null ELSE NULL END) as rand_null_perc,
	 avg(CASE WHEN enc_si   THEN enc_si_rand   / enc_si   ELSE NULL END) as rand_si_perc,
	 avg(enc_null - enc_null_rand) as nulls,
	 avg(predict) as pred,
	 avg(cmc_imeisv) as imeisv,
         -- FIXME: This calculates average of different authentication algorithms (none=0, GSM A3/A3=1, UMTS AKA=2).
         --        Does this make sense?
	 avg(CASE WHEN mobile_term THEN auth ELSE NULL END) as auth_mt,
	 avg(CASE WHEN mobile_orig THEN auth ELSE NULL END) as auth_mo,
	 avg(t_tmsi_realloc) as tmsi,
	 avg(iden_imsi_bc) as imsi
  from session_info
  where rat = 0 and (t_sms and (sms_presence or (cipher=1 and cracked=0) or cipher>1))
  group by mcc, mnc, lac, month, cipher
  order by mcc, mnc, lac, month, cipher;

drop view if exists loc_avg;
create view loc_avg as
  select mcc, mnc, lac, date_format(timestamp, "%Y-%m") as month, cipher,
	 count(*) as count,
	 sum(CASE WHEN mobile_orig THEN 1 ELSE 0 END) as mo_count,
	 avg(cracked) as success,
	 avg(CASE WHEN enc_null THEN enc_null_rand / enc_null ELSE NULL END) as rand_null_perc,
	 avg(CASE WHEN enc_si   THEN enc_si_rand   / enc_si   ELSE NULL END) as rand_si_perc,
	 avg(enc_null - enc_null_rand) as nulls,
	 avg(predict) as pred,
	 avg(cmc_imeisv) as imeisv,
         -- FIXME: This calculates average of different authentication algorithms (none=0, GSM A3/A3=1, UMTS AKA=2).
         --        Does this make sense?
	 avg(CASE WHEN mobile_term THEN auth ELSE NULL END) as auth_mt,
	 avg(CASE WHEN mobile_orig THEN auth ELSE NULL END) as auth_mo,
	 avg(t_tmsi_realloc) as tmsi,
	 avg(iden_imsi_bc) as imsi
  from session_info
  -- FIXME: Why do we ignore A5/1 here? Too little data?
  -- FIXME: Why do accepted LURQs not need to be encrypted (lu_acc or cipher > 1)?
  where rat = 0 and t_locupd and (lu_acc or cipher > 1)
  group by mcc, mnc, lac, month, cipher
  order by mcc, mnc, lac, month, cipher;

drop view if exists en;
create view en as
  select mcc, mnc, lac, cid, date_format(timestamp, "%Y-%m") as month, cipher,
	avg(a_ma_len + 1 - a_hopping) as a_len,
	variance((a_ma_len + 1 - a_hopping)/64) as v_len,
	variance(a_hsn/64) as v_hsn,
	variance(a_maio/64) as v_maio,
	variance(a_timeslot/8) as v_ts,
	variance(a_tsc/8) as v_tsc
  from session_info
  where rat = 0 and (assign or handover) and
  (cipher > 0 or duration > 350)
  group by mcc, mnc, lac, cid, month, cipher;

drop view if exists e;
create view e as
  select mcc, mnc, lac, month, cipher,
	 avg(a_len) as ma_len,
	 avg(v_len) as var_len,
	 avg(v_hsn) as var_hsn,
	 avg(v_maio) as var_maio,
	 avg(v_ts) as var_ts,
	 avg(v_tsc) as var_tsc
    from en
    group by mcc, mnc, lac, month, cipher
    order by mcc, mnc, lac, month, cipher;

-- "sec_params" population
delete from sec_params;

insert into sec_params
 select
        va.mcc                         as mcc,
        va.mnc                         as mnc,
        va.country                     as country,
        va.network                     as network,
        c.lac                          as lac,
        c.month                        as month,
        va.cipher                      as cipher,
        c.count                        as call_count,
        c.mo_count                     as call_mo_count,
        s.count                        as sms_count,
        s.mo_count                     as sms_mo_count,
        l.count                        as loc_count,
        c.success                      as call_success,
        s.success                      as sms_success,
        l.success                      as loc_success,
        c.rand_null_perc               as call_null_rand,
        s.rand_null_perc               as sms_null_rand,
        l.rand_null_perc               as loc_null_rand,
        c.rand_si_perc                 as call_si_rand,
        s.rand_si_perc                 as sms_si_rand,
        l.rand_si_perc                 as loc_si_rand,
        c.nulls                        as call_nulls,
        s.nulls                        as sms_nulls,
        l.nulls                        as loc_nulls,
        c.pred                         as call_pred,
        s.pred                         as sms_pred,
        l.pred                         as loc_pred,
        c.imeisv                       as call_imeisv,
        s.imeisv                       as sms_imeisv,
        l.imeisv                       as loc_imeisv,
        avg_of_2(c.auth_mt, s.auth_mt) as pag_auth_mt,
        c.auth_mo                      as call_auth_mo,
        s.auth_mo                      as sms_auth_mo,
        l.auth_mo                      as loc_auth_mo,
        c.tmsi                         as call_tmsi,
        s.tmsi                         as sms_tmsi,
        l.tmsi                         as loc_tmsi,
        c.imsi                         as call_imsi,
        s.imsi                         as sms_imsi,
        l.imsi                         as loc_imsi,
        e.ma_len                       as ma_len,
        e.var_len                      as var_len,
        e.var_hsn                      as var_hsn,
        e.var_maio                     as var_maio,
        e.var_ts                       as var_ts,
        h.rand_imsi                    as rand_imsi,
        h.home_routing                 as home_routing
 from
        va
        left outer join call_avg as c on (va.mcc = c.mcc and va.mnc = c.mnc and va.cipher = c.cipher)
        left outer join sms_avg  as s on (va.mcc = s.mcc and va.mnc = s.mnc and va.cipher = s.cipher and c.lac = s.lac and c.month = s.month)
        left outer join loc_avg  as l on (va.mcc = l.mcc and va.mnc = l.mnc and va.cipher = l.cipher and c.lac = l.lac and c.month = l.month)
        left outer join             e on (va.mcc = e.mcc and va.mnc = e.mnc and va.cipher = e.cipher and c.lac = e.lac and c.month = e.month)
        left outer join hlr_info as h on (va.mcc = h.mcc and va.mnc = h.mnc)
 where c.lac <> 0 and c.month <> ""
 order by mcc, mnc, lac, month, cipher; 

drop view call_avg;
drop view sms_avg;
drop view loc_avg;
drop view e;
drop view en;

--

-- "attack_component" population

delete from attack_component_x4;
insert into attack_component_x4
 select s.mcc, s.mnc, s.lac, s.month, s.cipher,

	s.call_count / t.call_tot as call_perc,

	s.sms_count  / t.sms_tot  as sms_perc,

	s.loc_count  / t.loc_tot  as loc_perc,

	avg_of_2
        (
                CASE WHEN call_nulls >  5 THEN 0 ELSE 1 - call_nulls /  5 END,
                CASE WHEN sms_nulls  > 10 THEN 0 ELSE 1 - sms_nulls  / 10 END
        )
        as realtime_crack,

	avg_of_2
        (
                CASE WHEN call_pred > 10 THEN 0 ELSE 1 - call_pred / 10 END,
                CASE WHEN sms_pred  > 15 THEN 0 ELSE 1 - sms_pred  / 15 END
        ) as offline_crack,

	pag_auth_mt as key_reuse_mt,

	avg_of_2(call_auth_mo,sms_auth_mo) as key_reuse_mo,

        --  FIXME: This value won't exceed 0.6 - is this on purpose?
	0.4 * avg_of_3 (call_tmsi, sms_tmsi, loc_tmsi) +
        0.2 * CASE WHEN loc_imsi < 0.05 THEN 1 - loc_imsi * 20 ELSE 0 END
           as track_tmsi,

	0.5 * rand_imsi + 0.5 * home_routing
           as hlr_inf,

	0.2 * CASE WHEN ma_len   < 8    THEN       ma_len  / 8 ELSE 1 END +
	0.2 * CASE WHEN var_len  < 0.01 THEN 100 * var_len     ELSE 1 END +
	0.2 * CASE WHEN var_hsn  < 0.01 THEN 100 * var_hsn     ELSE 1 END +
	0.2 * CASE WHEN var_maio < 0.1  THEN  10 * var_maio    ELSE 1 END +
	0.2 * CASE WHEN var_ts   < 0.1  THEN  10 * var_ts      ELSE 1 END
           as freq_predict

  from sec_params as s, lac_session_type_count as t
  where s.mcc = t.mcc and s.mnc = t.mnc and
	s.lac = t.lac and s.month = t.month
  order by s.mcc,s.mnc,s.lac,s.month,s.cipher;

delete from attack_component;
insert into attack_component
 select mcc, mnc, lac, month,

        sum(CASE
               WHEN cipher=3 THEN
                  (1.0 / 2 + realtime_crack / 2)
               WHEN cipher=2 THEN
                  0.2 / 2
               WHEN cipher=1 THEN
                  (0.5 / 2 + realtime_crack / 2)
               ELSE
                  0
            END * avg_of_2(call_perc,sms_perc)) as realtime_crack,

        sum(CASE
               WHEN cipher=3 THEN
                  (1.0 / 2 + offline_crack / 2)
               WHEN cipher=2 THEN
                   0.2 / 2
               WHEN cipher=1 THEN
                  (0.5 / 2 + offline_crack / 2)
               ELSE
                  0
            END * avg_of_2(call_perc,sms_perc)) as offline_crack,

        sum(avg_of_2(call_perc,sms_perc)*key_reuse_mt) as key_reuse_mt,

        sum(avg_of_2(call_perc,sms_perc)*key_reuse_mo) as key_reuse_mo,

        sum(CASE
               WHEN cipher=3 THEN
                    1 * 0.4 * avg_of_2(call_perc,sms_perc)
               WHEN cipher=2 THEN
                  0.2 * 0.4 * avg_of_2(call_perc,sms_perc)
               WHEN cipher=1 THEN
                  0.5 * 0.4 * avg_of_2(call_perc,sms_perc) + track_tmsi
               ELSE
                  0
            END) as track_imsi,

        avg(hlr_inf) as hlr_info,

        sum(call_perc * freq_predict) as freq_predict

 from attack_component_x4
 group by mcc, mnc, lac, month
 order by mcc, mnc, lac, month;

--

-- "risk_intercept" population
delete from risk_intercept;
insert into risk_intercept
 select mcc, mnc, lac, month,
	(realtime_crack*0.4
	+ offline_crack*0.25
	+ avg_of_2(key_reuse_mt, key_reuse_mo)*0.20
	+ freq_predict*0.15) as voice,
	offline_crack as sms
 from attack_component
 order by mcc, mnc, lac, month;

--

-- "risk_impersonation" population
delete from risk_impersonation;

insert into risk_impersonation
 select mcc, mnc, lac, month,
	avg_of_2(offline_crack, key_reuse_mo) as make_calls,
	avg_of_2(offline_crack, key_reuse_mt) as recv_calls
 from attack_component
 order by mcc, mnc, lac, month;

--

-- "risk_tracking" population
delete from risk_tracking;

insert into risk_tracking
 select mcc, mnc, lac, month,
	track_tmsi as local_track,
	hlr_inf as global_track
 from attack_component
 order by mcc, mnc, lac, month;

--

-- "risk_category" population
delete from risk_category;

insert into risk_category
 select inter.mcc, inter.mnc, inter.lac, inter.month,
	(inter.voice*0.8+inter.sms*0.2) as intercept,
	(imper.make_calls*0.7+imper.recv_calls*0.3) as impersonation,
	(track.local_track*0.3+track.global_track*0.7) as tracking
 from	risk_intercept as inter,
	risk_impersonation as imper,
	risk_tracking as track
 where inter.mcc = imper.mcc and imper.mcc = track.mcc
   and inter.mnc = imper.mnc and imper.mnc = track.mnc
   and inter.lac = imper.lac and imper.lac = track.lac
   and inter.month = imper.month and imper.month = track.month
 order by inter.mcc, inter.mnc, inter.lac, inter.month;

-- definition of views

drop view lac_session_type_count;
create view lac_session_type_count as
 select mcc, mnc, lac, month,
	sum(call_count) as call_tot,
	sum(sms_count) as sms_tot,
	sum(loc_count) as loc_tot
 from sec_params
 group by mcc,mnc,lac,month;
