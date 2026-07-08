@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Display log FI'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZFI_I_DIS_UP
  as select distinct from zfi_tb_upload

  association [1..1] to I_User         as I_User on $projection.pst_user = I_User.UserID
  composition [0..*] of ZFI_I_DIS_UP_I as _Item

{
      @EndUserText.label: 'Filename'
      @UI.lineItem: [ { position: 10, label: 'Filename' } ]
      @UI.selectionField: [ { position: 10 } ]
  key zfi_tb_upload.filename,

      @EndUserText.label: 'Entry Date'
      @UI.lineItem: [ { position: 100, label: 'Posting Date' } ]
      zfi_tb_upload.pst_date,

      @EndUserText.label: 'Posted by'
      @ObjectModel.text.element: [ 'UserDescription' ]
      @UI.lineItem: [ { position: 110, label: 'Posted by' } ]
      @UI.textArrangement: #TEXT_FIRST
      zfi_tb_upload.pst_user,


      @EndUserText.label: 'User Description'
      @UI.hidden: true
      i_user.UserDescription,

      @UI.hidden: true
      zfi_tb_upload.companycode,

      @UI.hidden: true
      zfi_tb_upload.fiscalyear,

      _Item
}
