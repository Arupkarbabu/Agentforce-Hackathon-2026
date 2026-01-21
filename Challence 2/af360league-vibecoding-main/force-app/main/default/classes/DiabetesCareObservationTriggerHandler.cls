public class DiabetesCareObservationTriggerHandler {
    
    public static void handleAfterInsert(List<CareObservation> newObservations) {
        processObservations(newObservations);
    }
    
    public static void handleAfterUpdate(List<CareObservation> newObservations) {
        processObservations(newObservations);
    }
    
    private static void processObservations(List<CareObservation> newObservations) {
        // Get thresholds from Custom Metadata (cached automatically)
        Diabetes_Threshold__mdt thresholds = [SELECT Target_Percentage__c, Warning_Percentage__c, Critical_Percentage__c
                                              FROM Diabetes_Threshold__mdt
                                              WHERE DeveloperName = 'Standard_Diabetes_Thresholds'
                                              LIMIT 1];

        List<Task> tasksToCreate = new List<Task>();
        Set<Id> observationIds = new Set<Id>();
        Set<Id> codeIds = new Set<Id>();
        Map<Id, Decimal> observationHbA1cMap = new Map<Id, Decimal>();

        // First pass: collect Code IDs to query
        for(CareObservation obs : newObservations) {
            if(obs.CodeId != null) {
                codeIds.add(obs.CodeId);
            }
        }

        // Query CodeSet records to get code names
        Map<Id, CodeSet> codeMap = new Map<Id, CodeSet>(
            [SELECT Id, Name FROM CodeSet WHERE Id IN :codeIds]
        );

        // Second pass: collect observation IDs and HbA1c values for bulk processing
        for(CareObservation obs : newObservations) {
            CodeSet code = codeMap.get(obs.CodeId);
            String codeName = code != null ? code.Name : null;

            System.debug('Code Name: ' + codeName);
            // Only process finalized HbA1c observations with valid data
            // Use metadata threshold instead of hardcoded 8.0
            if(codeName == 'HbA1c' &&
               obs.ObservationStatus == 'final' &&
               obs.ObservedValueType == 'Quantity' &&
               obs.ObservedValueNumerator != null &&
               obs.ObservedValueNumerator >= thresholds.Warning_Percentage__c && // Dynamic threshold!
               obs.ObservedSubjectId != null) {

                observationIds.add(obs.Id);
                observationHbA1cMap.put(obs.Id, obs.ObservedValueNumerator);
            }
        }

        if(!observationIds.isEmpty()) {
            // Fixed Bug 1: Query existing tasks in bulk outside the loop
            List<Task> existingTasks = [SELECT Id, WhatId FROM Task
                                       WHERE WhatId IN :observationIds
                                       AND Subject LIKE '%HbA1c Follow-up%'
                                       AND Status != 'Completed'
                                       AND CreatedDate = LAST_N_DAYS:30];

            // Create a set of observation IDs that already have tasks
            Set<Id> observationsWithTasks = new Set<Id>();
            for(Task t : existingTasks) {
                observationsWithTasks.add(t.WhatId);
            }

            // Process observations and create tasks in bulk
            for(Id observationId : observationIds) {
                // Only create task if no existing task found
                if(!observationsWithTasks.contains(observationId)) {
                    Decimal hba1cValue = observationHbA1cMap.get(observationId);

                    // Fixed Bug 3: Add null check for hba1cValue
                    if(hba1cValue != null) {
                        Task followUpTask = new Task();
                        followUpTask.Subject = 'HbA1c Follow-up Required - ' + Date.today().format();
                        followUpTask.WhatId = observationId; // Task linked to CareObservation record
                        
                        // Fixed Bug 2: Set required ActivityDate field
                        if(hba1cValue >= thresholds.Critical_Percentage__c) {
                            followUpTask.Priority = 'High';
                            followUpTask.ActivityDate = Date.today().addDays(1); // Next day for critical
                        } else if(hba1cValue >= thresholds.Warning_Percentage__c) {
                            followUpTask.Priority = 'Normal';
                            followUpTask.ActivityDate = Date.today().addDays(3); // 3 days for warning
                        } else {
                            followUpTask.Priority = 'Low';
                            followUpTask.ActivityDate = Date.today().addDays(7); // 1 week for low priority
                        }

                        followUpTask.Status = 'Not Started';
                        followUpTask.Type = 'Call';

                        followUpTask.Description = 'Patient has new HbA1c level of ' +
                                                 hba1cValue + '%. Schedule follow-up appointment to review ' +
                                                 'diabetes management plan and medication adherence. ' +
                                                 'Thresholds: Target <' + thresholds.Target_Percentage__c +
                                                 '%, Warning ≥' + thresholds.Warning_Percentage__c +
                                                 '%, Critical ≥' + thresholds.Critical_Percentage__c + '%.';

                        tasksToCreate.add(followUpTask);
                    }
                }
            }
            
            // Fixed Bug 4: Bulk DML operation outside loop
            if(!tasksToCreate.isEmpty()) {
                insert tasksToCreate;
            }
        }
    }
}

