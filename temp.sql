/****** Object:  StoredProcedure [PROD].[SP_ATYPE_DailyProductionPlan]    Script Date: 26-09-2025 15:28:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [PROD].[SP_ATYPE_DailyProductionPlan]
as 
begin

drop table if exists #tempbtype1;
drop table if  exists ##TempVaildMatCodePlanTemp;

select t.MaterialCode,t.ForecastDate,t.[Plan],t.TrialProduct,t.RevisionComment,upper(t.[Line]) as Line,upper(t.Process) as Process
into ##TempVaildMatCodePlanTemp
from [PROD].[atype_dailyproductionplan_temp] t
join (select distinct MaterialCode,upper(Line) as Line,upper(ProcessName) as ProcessName from [PROD].[ATYPE_MaterialMaster]) m
on t.MaterialCode=m.MaterialCode
and t.Line=m.Line
and t.Process=m.ProcessName;


with daterange as (
    select distinct
        materialcode,
        trialproduct,
        revisioncomment,
        Line,
        process,
        cast(dateadd(month, datediff(month, 0, try_parse(forecastdate as date using 'en-gb')), 0) as date) as startdate,
        eomonth(try_parse(forecastdate as date using 'en-gb')) as enddate
    from ##TempVaildMatCodePlanTemp
),
cte2 as (
    select d.Date, dr.*
    from dbo.date d
    join daterange dr
    on d.Date between dr.startdate and dr.enddate
)
select 
    d.materialcode,
    d.Date as forecastdate,
    isnull(t.[plan], 0) as [plan],
    d.trialproduct,
    d.revisioncomment,
    d.line,
    d.process,
    d.startdate,
    d.enddate
into #tempbtype1
from cte2 d
left join ##TempVaildMatCodePlanTemp t 
    on d.materialcode = t.materialcode
    and d.Date = try_parse(t.forecastdate as date using 'en-gb')
    and d.trialproduct = t.trialproduct
    and d.line = t.line
    and d.process = t.process


update target
set isactive = 0
output 
    s.materialcode,
    s.forecastdate,
    case when inserted.[Plan]<>so.[plan] then isnull(so.[plan],0) else isnull(inserted.[plan],0) end as [plan],
    s.trialproduct,
    1 as isactive,
    isnull(deleted.revisionnumber, 0) + 1 as revisionnumber,
    coalesce(s.revisioncomment,s.revisioncomment),
    s.line,
    s.process
into [PROD].[atype_dailyproductionplan] (materialcode, forecastdate, [plan], trialproduct, isactive, revisionnumber, revisioncomment, line, process)
--select *
from [PROD].atype_dailyproductionplan target
left join #tempbtype1 s
    on target.materialcode = s.materialcode
    and target.forecastdate = s.forecastdate
    and target.trialproduct = s.trialproduct
    and target.line = s.line
    and target.process = s.process
left join ##TempVaildMatCodePlanTemp so
    on target.materialcode = so.materialcode
    and target.forecastdate = try_parse(so.forecastdate as date using 'en-gb')
    and target.trialproduct = so.trialproduct
    and target.line = so.line
    and target.process = so.process
where target.isactive = 1
and hashbytes('md5', concat(
    target.materialcode, '|',
    target.line, '|',
    target.process, '|',
    target.trialproduct, '|',
    year(target.forecastdate), '|',
    month(target.forecastdate)
)) in (
    select distinct hashbytes('md5', concat(
        s.materialcode, '|',
        s.line, '|',
        s.process, '|',
        s.trialproduct, '|',
        year(try_parse(s.forecastdate as date using 'en-gb')), '|',
        month(try_parse(s.forecastdate as date using 'en-gb'))
    ))
    from [PROD].atype_dailyproductionplan t
    join ##TempVaildMatCodePlanTemp s 
        on t.forecastdate = try_parse(s.forecastdate as date using 'en-gb')
        and t.materialcode = s.materialcode
        and t.trialproduct = s.trialproduct
        and t.line = s.line
        and t.process = s.process
    where t.IsActive=1 and s.[plan] != t.[plan]
);


insert into [PROD].atype_dailyproductionplan (
    materialcode, forecastdate, [plan], trialproduct, isactive, revisionnumber, revisioncomment, line, process
)
select 
    s.materialcode,
    s.forecastdate,
    s.[plan],
    s.trialproduct,
    1 as isactive,
    0 as revisionnumber,
    s.revisioncomment,
    s.line,
    s.process
from #tempbtype1 s
left join [PROD].atype_dailyproductionplan t
    on s.materialcode = t.materialcode
    and s.forecastdate = t.forecastdate
    and s.line = t.line
    and s.process = t.process
    and s.trialproduct = t.trialproduct
where t.materialcode is null;

truncate table [PROD].[ATYPE_DailyProductionPlan_Temp];
end;

GO


