@AbapCatalog.viewEnhancementCategory: [ #NONE ]

@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Data definition - Value help cho Product'

@Metadata.ignorePropagatedAnnotations: true

@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }

define view entity ZPP_I_PRODUCT_SVH
  as select from I_Product

  association [0..1] to I_ProductText       as _Text
    on  $projection.Product = _Text.Product
    and _Text.Language      = $session.system_language

  association [1..1] to I_ProductionVersion as _ProductionVersion
    on $projection.Product = _ProductionVersion.Material

{
  key Product,

      _Text.ProductName
}
  
