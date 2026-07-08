@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value help cho Production Order Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZPP_I_ProductionOrderType_SVH
  as select from I_OrderTypeText
{
      @ObjectModel.text.element: ['ProductionOrderTypeName']
      @Search.defaultSearchElement: true
  key OrderType     as ProductionOrderType,

      @Semantics.text: true
      @Search: { defaultSearchElement: true, fuzzinessThreshold: 0.8 }
      OrderTypeName as ProductionOrderTypeName
}
where Language = $session.system_language
