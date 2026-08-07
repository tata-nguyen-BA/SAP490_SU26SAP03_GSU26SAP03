@EndUserText.label: 'PO Lookup for GR'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZMM_C_PO_LOOKUP
  as select from zmm_i_po_lookup
{
  key PurchaseOrder,
  key PurchaseOrderItem,

      Supplier,
      CompanyCode,
      PurchaseOrderType,
      ReleaseBlockIndicator,
      PurchasingGroup,
      PurchasingOrganization,
      PurchaseOrderDate,
      Material,
      Plant,
      StorageLocation,
      OrderQuantity,
      GoodsReceiptQuantity,
      OpenQuantity,
      OrderUnit,
      ShortText,
      BatchManaged,
      DeletionCode,
      DeliveryIsCompleted,
      GoodsReceiptIndicator
}
