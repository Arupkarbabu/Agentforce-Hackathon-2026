/**
 * @description Apex class for assessing diabetes care based on HbA1c values and program enrollment.
 *              Designed to be invocable from Flow, Process Builder, or other automation tools.
 * @author Salesforce
 * @date 2026
 */
public with sharing class DiabetesCareAssessment {
    
    /**
     * @description Input wrapper class for the invocable method
     */
    public class AssessmentRequest {
        @InvocableVariable(label='Patient ID' description='The Salesforce ID of the patient/account to assess' required=true)
        public Id patientId;
        
        @InvocableVariable(label='Days Lookback' description='Number of days to look back for observations' required=true)
        public Integer daysLookback;
        
        /**
         * @description Default no-argument constructor
         */
        public AssessmentRequest() {
        }
        
        /**
         * @description Parameterized constructor
         * @param patientId The patient/account ID
         * @param daysLookback Number of days to look back
         */
        public AssessmentRequest(Id patientId, Integer daysLookback) {
            this.patientId = patientId;
            this.daysLookback = daysLookback;
        }
    }
    
    /**
     * @description Output wrapper class for the invocable method
     */
    public class AssessmentResult {
        @InvocableVariable(label='Patient ID' description='The Salesforce ID of the patient that was assessed')
        public Id patientId;
        
        @InvocableVariable(label='HbA1c Value' description='The latest HbA1c value found for the patient')
        public Decimal hba1cValue;
        
        @InvocableVariable(label='Risk Category' description='Categorized risk level based on HbA1c value')
        public String riskCategory;
        
        @InvocableVariable(label='Is In Diabetes Program' description='Indicates whether the patient is enrolled in an active Diabetes care program')
        public Boolean isInDiabetesProgram;
        
        @InvocableVariable(label='Error Message' description='Contains error message if processing failed for this patient')
        public String errorMessage;
        
        /**
         * @description Default no-argument constructor
         */
        public AssessmentResult() {
        }
        
        /**
         * @description Parameterized constructor
         * @param patientId The patient/account ID
         */
        public AssessmentResult(Id patientId) {
            this.patientId = patientId;
        }
    }
    
    /**
     * @description Invocable method to assess patient diabetes care based on HbA1c values and program enrollment
     * @param requests List of assessment requests containing patient IDs
     * @return List of assessment results with HbA1c values, risk categories, and program enrollment status
     */
    @InvocableMethod(label='Assess Patient' description='Assesses patient diabetes care based on HbA1c values and program enrollment')
    public static List<AssessmentResult> assessPatient(List<AssessmentRequest> requests) {
        List<AssessmentResult> results = new List<AssessmentResult>();
        
        // Input validation
        if(requests == null || requests.isEmpty()) {
            return results;
        }
        
        // Extract patient IDs
        Set<Id> patientIds = new Set<Id>();
        Map<Id, AssessmentRequest> requestMap = new Map<Id, AssessmentRequest>();
        
        for(AssessmentRequest req : requests) {
            if(req.patientId != null) {
                patientIds.add(req.patientId);
                requestMap.put(req.patientId, req);
            }
        }
        
        // Get HbA1c CodeSet
        Id hba1cCodeSetId = getHbA1cCodeSetId();
        
        if(hba1cCodeSetId == null) {
            // If no HbA1c CodeSet found, create error results for all patients
            for(Id patientId : patientIds) {
                AssessmentResult result = new AssessmentResult(patientId);
                result.errorMessage = 'HbA1c CodeSet not found in the system';
                results.add(result);
            }
            return results;
        }
        
        // Retrieve data
        Map<Id, CareObservation> latestObservations = getLatestHbA1cObservations(patientIds, hba1cCodeSetId);
        Map<Id, Boolean> programEnrollmentMap = checkActiveDiabetesPrograms(patientIds);
        
        // Process results
        for(Id patientId : patientIds) {
            AssessmentResult result = new AssessmentResult(patientId);
            
            try {
                // Get latest observation
                CareObservation observation = latestObservations.get(patientId);
                
                if(observation != null && observation.ObservedValueNumerator != null) {
                    result.hba1cValue = observation.ObservedValueNumerator;
                    
                    // Categorize risk based on HbA1c value
                    if(result.hba1cValue < 7.0) {
                        result.riskCategory = 'Well Controlled';
                    } else if(result.hba1cValue >= 7.0 && result.hba1cValue < 9.0) {
                        result.riskCategory = 'Needs Attention';
                    } else if(result.hba1cValue >= 9.0) {
                        result.riskCategory = 'High Risk/Urgent';
                    }
                } else {
                    result.riskCategory = 'No Data Available';
                }
                
                // Set program enrollment status
                result.isInDiabetesProgram = programEnrollmentMap.get(patientId) != null ? 
                                            programEnrollmentMap.get(patientId) : false;
                
            } catch(Exception e) {
                result.errorMessage = 'Error processing patient ' + patientId + ': ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * @description Retrieves the Salesforce ID of the CodeSet record named 'HbA1c'
     * @return Id of the HbA1c CodeSet, or null if not found
     */
    private static Id getHbA1cCodeSetId() {
        List<CodeSet> codeSets = [SELECT Id FROM CodeSet WHERE Name = 'HbA1c' LIMIT 1];
        return codeSets.isEmpty() ? null : codeSets[0].Id;
    }
    
    /**
     * @description Retrieves the most recent HbA1c observation for each patient
     * @param patientIds Set of patient/account IDs to query
     * @param hba1cCodeSetId The ID of the HbA1c CodeSet
     * @return Map of patient IDs to their latest CareObservation records
     */
    private static Map<Id, CareObservation> getLatestHbA1cObservations(Set<Id> patientIds, Id hba1cCodeSetId) {
        Map<Id, CareObservation> observationMap = new Map<Id, CareObservation>();
        
        // Early return if inputs are invalid
        if(patientIds == null || patientIds.isEmpty() || hba1cCodeSetId == null) {
            return observationMap;
        }
        
        // Query CareObservation records
        List<CareObservation> observations = [
            SELECT Id, ObservedSubjectId, ObservedValueNumerator, EffectiveDateTime
            FROM CareObservation
            WHERE CodeId = :hba1cCodeSetId
            AND ObservedSubjectId IN :patientIds
            AND ObservationStatus = 'Final'
            AND ObservedValueType = 'Quantity'
            AND ObservedValueNumerator != null
            ORDER BY EffectiveDateTime DESC NULLS LAST
            LIMIT 1000
        ];
        
        // Create map with one observation per patient (latest due to ordering)
        for(CareObservation obs : observations) {
            if(!observationMap.containsKey(obs.ObservedSubjectId)) {
                observationMap.put(obs.ObservedSubjectId, obs);
            }
        }
        
        return observationMap;
    }
    
    /**
     * @description Determines which patients are enrolled in active Diabetes care programs
     * @param patientIds Set of patient/account IDs to check
     * @return Map of patient IDs to their enrollment status (true if enrolled, false otherwise)
     */
    private static Map<Id, Boolean> checkActiveDiabetesPrograms(Set<Id> patientIds) {
        Map<Id, Boolean> enrollmentMap = new Map<Id, Boolean>();
        
        // Early return if input is invalid
        if(patientIds == null || patientIds.isEmpty()) {
            return enrollmentMap;
        }
        
        // Initialize all patients as not enrolled
        for(Id patientId : patientIds) {
            enrollmentMap.put(patientId, false);
        }
        
        // Query CareProgramEnrollee records
        List<CareProgramEnrollee> enrollees = [
            SELECT Id, CareProgramId, AccountId, Status
            FROM CareProgramEnrollee
            WHERE AccountId IN :patientIds
            AND Status = 'Active'
            AND CareProgramId IN (SELECT Id FROM CareProgram WHERE Name LIKE '%Diabetes%')
        ];
        
        // Mark enrolled patients
        for(CareProgramEnrollee enrollee : enrollees) {
            enrollmentMap.put(enrollee.AccountId, true);
        }
        
        return enrollmentMap;
    }
}
