@EndUserText.label: 'PO Lookup for GR Validation'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity zmm_i_po_lookup
  as select from ekpo as poi
    inner join   ekko as po on po.ebeln = poi.ebeln
{
  key poi.ebeln as PurchaseOrder,
  key poi.ebelp as PurchaseOrderItem,

      po.lifnr  as Supplier,
      po.bsart  as PurchaseOrderType,
      po.frgrl  as ReleaseBlockIndicator,
      poi.matnr as Material,
      poi.werks as Plant,
      poi.lgort as StorageLocation,
      poi.menge as OrderQuantity,
      poi.meins as OrderUnit,
      poi.txz01 as ShortText,


      poi.loekz as DeletionCode,
      poi.elikz as DeliveryIsCompleted,
      poi.wepos as GoodsReceiptIndicator
}
where
      poi.loekz <> 'L'
  and po.frgrl  =  ''
