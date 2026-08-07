define view entity zmm_i_po_lookup
   as select from    ekpo            as poi
    inner join      ekko            as po on po.ebeln = poi.ebeln
    left outer join marc            as mc on  mc.matnr = poi.matnr
                                          and mc.werks = poi.werks
    left outer join ZMM_I_PO_GR_QTY as gr on  gr.PurchaseOrder     = poi.ebeln
                                          and gr.PurchaseOrderItem = poi.ebelp
{
  key poi.ebeln                                                            as PurchaseOrder,
  key poi.ebelp                                                            as PurchaseOrderItem,

      po.lifnr                                                             as Supplier,
      po.bukrs                                                             as CompanyCode,
      po.bsart                                                             as PurchaseOrderType,
      po.frgrl                                                             as ReleaseBlockIndicator,
      po.ekgrp                                                             as PurchasingGroup,
      po.ekorg                                                             as PurchasingOrganization,
      po.bedat                                                             as PurchaseOrderDate,
      poi.matnr                                                            as Material,
      poi.werks                                                            as Plant,
      poi.lgort                                                            as StorageLocation,
      poi.menge                                                            as OrderQuantity,

      @Semantics.quantity.unitOfMeasure: 'OrderUnit'
      cast( coalesce( gr.GoodsReceiptQuantity, 0 ) as abap.quan( 13, 3 ) ) as GoodsReceiptQuantity,

      @Semantics.quantity.unitOfMeasure: 'OrderUnit'
      cast( cast( poi.menge as abap.dec( 13, 3 ) ) - coalesce( gr.GoodsReceiptQuantity, 0 )
            as abap.quan( 13, 3 ) )                                        as OpenQuantity,

      poi.meins                                                            as OrderUnit,
      poi.txz01                                                            as ShortText,
      mc.xchpf                                                             as BatchManaged,

      poi.loekz                                                            as DeletionCode,
      poi.elikz                                                            as DeliveryIsCompleted,
      poi.wepos                                                            as GoodsReceiptIndicator
}
where
      poi.loekz <> 'L'
  and po.frgrl  =  ''
