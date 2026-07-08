@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Kiểm tra material được upload có hợp lệ'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
/*
  Bản on-prem của zpp_i_upload_po_valid_material.
  Cloud dùng I_ProductionVersion + I_SalesOrderItem (VDM, chưa chắc có trên on-prem)
  -> viết lại từ bảng gốc, chắc chắn tồn tại trên mọi bản:
     MKAL = Production Version (key MATNR/WERKS/VERID, TEXT1 = mô tả)
     VBAP = Sales Order Item
  Giữ nguyên semantics: left outer join theo Material như bản cloud.
*/
define view entity zpp_i_upload_po_valid_material
  as select from    mkal as _ProdVer
    left outer join vbap as _SoItem on _SoItem.matnr = _ProdVer.matnr
{
  key _ProdVer.matnr as Material,
  key _ProdVer.werks as Plant,
  key _ProdVer.verid as ProductionVersion,

      _ProdVer.text1 as ProductionVersionText,

      _SoItem.vbeln  as SalesOrder,
      _SoItem.posnr  as SalesOrderItem
}
