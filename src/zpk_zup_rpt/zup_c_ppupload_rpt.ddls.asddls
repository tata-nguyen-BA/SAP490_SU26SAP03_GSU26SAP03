@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PP Upload Analytics Report'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZUP_C_PPUPLOAD_RPT
  as select from zpp_tb_zuplsx        as _Log
    left outer join aufk              as _Ord  on  _Ord.aufnr = _Log.productionorder

    left outer join jest              as _Rel  on  _Rel.objnr = _Ord.objnr
                                               and _Rel.stat  = 'I0002'
                                               and _Rel.inact = ''
    left outer join jest              as _Cnf  on  _Cnf.objnr = _Ord.objnr
                                               and _Cnf.stat  = 'I0009'
                                               and _Cnf.inact = ''
    left outer join jest              as _Teco on  _Teco.objnr = _Ord.objnr
                                               and _Teco.stat  = 'I0045'
                                               and _Teco.inact = ''
    left outer join jest              as _Clsd on  _Clsd.objnr = _Ord.objnr
                                               and _Clsd.stat  = 'I0046'
                                               and _Clsd.inact = ''
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

      // Xếp từ trạng thái cuối vòng đời ngược về đầu. Một lệnh đã Closed
      // vẫn còn cờ Released, nên phải kiểm Closed trước.
      // Nhánh cuối: có mặt trong AUFK nghĩa là lệnh đã được tạo.
      case
        when _Clsd.objnr is not initial then 'Closed'
        when _Teco.objnr is not initial then 'TECO'
        when _Cnf.objnr  is not initial then 'Completed'
        when _Rel.objnr  is not initial then 'Released'
        when _Ord.aufnr  is not initial then 'Created'
        else 'N/A'
      end                      as OrderStatus,

      _Log.filename            as Filename,
      _Log.pst_date            as PstDate,
      _Log.pst_user            as PstUser
}

