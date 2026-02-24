@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Child interface view'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_22CS083_USER_DEV
  as select from z22cs083_dev
  association to parent ZI_22CS083_USER as _User on  $projection.EmpID = _User.EmpID
                                                 and $projection.DevID = _User.DevID
{
  key emp_id      as EmpID,
  key dev_id      as DevID,
  key serial_no   as SerialNo,
      object_type as ObjectType,
      object_name as ObjectName,
      _User
}
