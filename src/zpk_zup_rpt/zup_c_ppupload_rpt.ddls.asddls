@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PP Upload Analytics Report'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZUP_C_PPUPLOAD_RPT
  as select from zpp_tb_zuplsx        as _Log
    left outer join aufk              as _Ord on _Ord.aufnr = _Log.productionorder
{
  key _Log.productionorder     as ProductionOrder,
  key _Log.material            as Material,
  key _Log.productionplant     as ProductionPlant,
  key _Log.productionversion   as ProductionVersion,
  key _Log.productionordertype as ProductionOrderType,
      _Log.iddoc               as IdDoc,
      _Log.salesorder          as SalesOrder,
      _Log.salesorderitem      as SalesOrderItem,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      _Log.totalqty            as TotalQty,
      _Log.baseunit            as BaseUnit,
      _Log.startdate           as StartDate,
      _Log.enddate             as EndDate,
      dats_days_between( _Log.startdate, _Log.enddate ) as LeadTimeDays,
      case
        when _Ord.phas3 = 'X' then 'Closed'
        when _Ord.phas2 = 'X' then 'Completed'
        when _Ord.phas1 = 'X' then 'Released'
        when _Ord.phas0 = 'X' then 'Created'
        else 'N/A'
      end                      as OrderStatus,
      _Ord.idat1               as ReleaseDate,
      _Log.filename            as Filename,
      _Log.pst_date            as PstDate,
      _Log.pst_user            as PstUser
}
