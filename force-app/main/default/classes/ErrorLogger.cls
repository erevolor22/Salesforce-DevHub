/**
 * @description : Error Logger class to log errors occured during transactions.g new users will be added.
 */
public class ErrorLogger {

    /**
     * @description : Method to get errors occured in insert and update DML. It saves Failed Reason
     * and Failed Record Id in Error Log object
     * User gets updated for Transfer record type.
     * @param : List<sObject> sObjectList
     * @param : Database.SaveResult[] srList
     * @return: void.
     */
    public static void logDMLErrors(sObject[] sObjectList, Database.SaveResult[] srList) {
      // Iterate through each returned result
      List<Error_Log__c> errorLogList = new List<Error_Log__c>();
      for (Integer i = 0; i < sObjectList.size(); i++) {
        Database.SaveResult s = srList[i];
        sObject origRecord = sObjectList[i];
        System.debug('s.isSuccess()'+s.isSuccess());
        if (!s.isSuccess()) {
          for(Database.Error err : s.getErrors()) {
            errorLogList.add(new Error_Log__c(
                Failed_Record_Id__c = (Id)origRecord.get('Id'),
                Failed_Reason__c =  err.getMessage().substring(0, Math.min(err.getMessage().length(), 255))  
            ));
          }
        } 
      }
      insert errorLogList;
    }
    
      public static void logUpsertErrors( List <Database.UpsertResult> results, String strClassName ) {
          // Iterate through each returned result
          List < Error_Log__c > errorLogList = new List < Error_Log__c >();
          for ( Database.UpsertResult s : results ){
              if ( !s.isSuccess() ) {
                  for ( Database.Error err : s.getErrors() ) {
                      errorLogList.add( new Error_Log__c(
                          Apex_Class_Name__c = strClassName,
                          Failed_Reason__c =  err.getMessage().substring( 0, Math.min( err.getMessage().length(), 255 ) ),
                          Failed_Record_Id__c = s.getId()
                      ));
                  }
              } 
          }
          if(errorLogList.size() > 0){
              insert errorLogList;
          }
      
      }
    
  }