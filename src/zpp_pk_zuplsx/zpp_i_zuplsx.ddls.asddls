@AbapCatalog.viewEnhancementCategory: [ #NONE ]

@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Hiện thị thông tin các lệnh sản xuất được upload'

@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true

@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }

@Search.searchable: false

define root view entity ZPP_I_ZUPLSX
  as select from    zpp_tb_zuplsx                 as ZSUP

    left outer join I_ProductionVersion           as PV  on  ZSUP.productionversion = PV.ProductionVersion
                                                         and ZSUP.material          = PV.Material
                                                         and ZSUP.productionplant   = PV.Plant

    left outer join ZPP_I_PRODUCT_SVH             as PSV on PSV.Product = ZSUP.material

    left outer join ZPP_I_ProductionOrderType_SVH as POT on POT.ProductionOrderType = ZSUP.productionordertype

    left outer join I_PlantStdVH                  as PS  on PS.Plant = ZSUP.productionplant

    left outer join I_ProductionOrderStdVH        as PO  on  PO.ProductionOrder = ZSUP.productionorder
                                                         and PO.ProductionPlant = ZSUP.productionplant
  //                                                         and PO.ProductionOrderType = ZSUP.productionordertype

    left outer join I_ManufacturingOrder          as MO  on MO.ManufacturingOrder = ZSUP.productionorder


{
  key ZSUP.material            as Material,

      @ObjectModel.text.element: [ 'PlantName' ]
      @UI.textArrangement: #TEXT_LAST
  key ZSUP.productionplant     as ProductionPlant,

      @ObjectModel.text.element: [ 'ProductionOrderText' ]
      @UI.textArrangement: #TEXT_LAST
  key ZSUP.productionorder     as ProductionOrder,

      @ObjectModel.text.element: [ 'ProductionOrderTypeName' ]
      @UI.textArrangement: #TEXT_LAST
  key ZSUP.productionordertype as ProductionOrderType,

      @ObjectModel.text.element: [ 'ProductionVersionText' ]
      @UI.textArrangement: #TEXT_LAST
  key ZSUP.productionversion   as ProductionVersion,


      ZSUP.salesorder          as SalesOrder,
      ZSUP.salesorderitem      as SalesOrderItem,

      ZSUP.baseunit            as BaseUnit,


      PSV.ProductName,

      @UI.hidden: true
      POT.ProductionOrderTypeName,

      @UI.hidden: true
      PV.ProductionVersionText,
      @UI.hidden: true
      PS.PlantName,

      ZSUP.iddoc               as IdDoc,
      ZSUP.totalqty            as TotalQty,

      ZSUP.startdate           as StartDate,
      ZSUP.enddate             as EndDate,
      ZSUP.filename            as Filename,
      ZSUP.pst_date            as PstDate,
      ZSUP.pst_user            as PstUser
}
