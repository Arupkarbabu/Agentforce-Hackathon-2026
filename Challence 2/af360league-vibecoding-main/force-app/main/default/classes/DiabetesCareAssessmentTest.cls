/**
 * @description Test class for DiabetesCareAssessment
 * @author Salesforce
 * @date 2026
 */
@isTest
private class DiabetesCareAssessmentTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test CodeSet for HbA1c
        CodeSet hba1cCodeSet = new CodeSet(
            Name = 'HbA1c',
            Type = 'Laboratory'
        );
        insert hba1cCodeSet;
        
        // Create test Account (Patient)
        Account patient = new Account(
            FirstName = 'Test',
            LastName = 'Patient',
            PersonEmail = 'test.patient@example.com'
        );
        insert patient;
        
        // Create test CareProgram
        CareProgram diabetesProgram = new CareProgram(
            Name = 'Diabetes Management Program',
            Status = 'Active',
            StartDate = Date.today().addDays(-30)
        );
        insert diabetesProgram;
        
        // Create test CareProgramEnrollee
        CareProgramEnrollee enrollee = new CareProgramEnrollee(
            AccountId = patient.Id,
            CareProgramId = diabetesProgram.Id,
            Status = 'Active'
        );
        insert enrollee;
        
        // Create test CareObservation with high HbA1c
        CareObservation observation = new CareObservation(
            Name = 'HbA1c Test',
            CodeId = hba1cCodeSet.Id,
            ObservedSubjectId = patient.Id,
            ObservationStatus = 'Final',
            ObservedValueType = 'Quantity',
            ObservedValueNumerator = 9.5,
            EffectiveDateTime = DateTime.now()
        );
        insert observation;
    }
    
    @isTest
    static void testAssessPatient_HighRisk() {
        // Get test patient
        Account patient = [SELECT Id FROM Account LIMIT 1];
        
        // Create assessment request
        DiabetesCareAssessment.AssessmentRequest request = new DiabetesCareAssessment.AssessmentRequest();
        request.patientId = patient.Id;
        request.daysLookback = 30;
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>{request});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        DiabetesCareAssessment.AssessmentResult result = results[0];
        
        System.assertEquals(patient.Id, result.patientId, 'Patient ID should match');
        System.assertEquals(9.5, result.hba1cValue, 'HbA1c value should be 9.5');
        System.assertEquals('High Risk/Urgent', result.riskCategory, 'Risk category should be High Risk/Urgent');
        System.assertEquals(true, result.isInDiabetesProgram, 'Patient should be in diabetes program');
        System.assertEquals(null, result.errorMessage, 'Should have no error message');
    }
    
    @isTest
    static void testAssessPatient_NeedsAttention() {
        // Get test patient and update observation to 7.5%
        Account patient = [SELECT Id FROM Account LIMIT 1];
        CareObservation obs = [SELECT Id FROM CareObservation LIMIT 1];
        obs.ObservedValueNumerator = 7.5;
        update obs;
        
        // Create assessment request
        DiabetesCareAssessment.AssessmentRequest request = new DiabetesCareAssessment.AssessmentRequest();
        request.patientId = patient.Id;
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>{request});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        DiabetesCareAssessment.AssessmentResult result = results[0];
        
        System.assertEquals('Needs Attention', result.riskCategory, 'Risk category should be Needs Attention');
    }
    
    @isTest
    static void testAssessPatient_WellControlled() {
        // Get test patient and update observation to 6.5%
        Account patient = [SELECT Id FROM Account LIMIT 1];
        CareObservation obs = [SELECT Id FROM CareObservation LIMIT 1];
        obs.ObservedValueNumerator = 6.5;
        update obs;
        
        // Create assessment request
        DiabetesCareAssessment.AssessmentRequest request = new DiabetesCareAssessment.AssessmentRequest();
        request.patientId = patient.Id;
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>{request});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        DiabetesCareAssessment.AssessmentResult result = results[0];
        
        System.assertEquals('Well Controlled', result.riskCategory, 'Risk category should be Well Controlled');
    }
    
    @isTest
    static void testAssessPatient_NoData() {
        // Create new patient without observations
        Account patient2 = new Account(
            FirstName = 'Test2',
            LastName = 'Patient2',
            PersonEmail = 'test2.patient@example.com'
        );
        insert patient2;
        
        // Create assessment request
        DiabetesCareAssessment.AssessmentRequest request = new DiabetesCareAssessment.AssessmentRequest();
        request.patientId = patient2.Id;
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>{request});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        DiabetesCareAssessment.AssessmentResult result = results[0];
        
        System.assertEquals('No Data Available', result.riskCategory, 'Risk category should be No Data Available');
        System.assertEquals(null, result.hba1cValue, 'HbA1c value should be null');
    }
    
    @isTest
    static void testAssessPatient_NotInProgram() {
        // Create new patient not enrolled in program
        Account patient2 = new Account(
            FirstName = 'Test2',
            LastName = 'Patient2',
            PersonEmail = 'test2.patient@example.com'
        );
        insert patient2;
        
        // Create observation for this patient
        CodeSet hba1cCodeSet = [SELECT Id FROM CodeSet WHERE Name = 'HbA1c' LIMIT 1];
        CareObservation observation = new CareObservation(
            Name = 'HbA1c Test 2',
            CodeId = hba1cCodeSet.Id,
            ObservedSubjectId = patient2.Id,
            ObservationStatus = 'Final',
            ObservedValueType = 'Quantity',
            ObservedValueNumerator = 8.0,
            EffectiveDateTime = DateTime.now()
        );
        insert observation;
        
        // Create assessment request
        DiabetesCareAssessment.AssessmentRequest request = new DiabetesCareAssessment.AssessmentRequest();
        request.patientId = patient2.Id;
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>{request});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, results.size(), 'Should return one result');
        DiabetesCareAssessment.AssessmentResult result = results[0];
        
        System.assertEquals(false, result.isInDiabetesProgram, 'Patient should not be in diabetes program');
    }
    
    @isTest
    static void testAssessPatient_EmptyRequest() {
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(new List<DiabetesCareAssessment.AssessmentRequest>());
        Test.stopTest();
        
        // Verify results
        System.assertEquals(0, results.size(), 'Should return empty list for empty request');
    }
    
    @isTest
    static void testAssessPatient_NullRequest() {
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(null);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(0, results.size(), 'Should return empty list for null request');
    }
    
    @isTest
    static void testAssessPatient_MultiplePatients() {
        // Get existing patient
        Account patient1 = [SELECT Id FROM Account LIMIT 1];
        
        // Create second patient
        Account patient2 = new Account(
            FirstName = 'Test2',
            LastName = 'Patient2',
            PersonEmail = 'test2.patient@example.com'
        );
        insert patient2;
        
        // Create observation for second patient
        CodeSet hba1cCodeSet = [SELECT Id FROM CodeSet WHERE Name = 'HbA1c' LIMIT 1];
        CareObservation observation = new CareObservation(
            Name = 'HbA1c Test 2',
            CodeId = hba1cCodeSet.Id,
            ObservedSubjectId = patient2.Id,
            ObservationStatus = 'Final',
            ObservedValueType = 'Quantity',
            ObservedValueNumerator = 6.0,
            EffectiveDateTime = DateTime.now()
        );
        insert observation;
        
        // Create assessment requests
        List<DiabetesCareAssessment.AssessmentRequest> requests = new List<DiabetesCareAssessment.AssessmentRequest>();
        
        DiabetesCareAssessment.AssessmentRequest request1 = new DiabetesCareAssessment.AssessmentRequest();
        request1.patientId = patient1.Id;
        requests.add(request1);
        
        DiabetesCareAssessment.AssessmentRequest request2 = new DiabetesCareAssessment.AssessmentRequest();
        request2.patientId = patient2.Id;
        requests.add(request2);
        
        Test.startTest();
        List<DiabetesCareAssessment.AssessmentResult> results = 
            DiabetesCareAssessment.assessPatient(requests);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(2, results.size(), 'Should return two results');
    }
}
