//
//  CourseContentView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import SwiftUI
import Auth
import Supabase
import PostgREST

struct CourseContentView: View {
    let course: TrainingCourse
    @StateObject private var academyService = AcademyService()
    @StateObject private var storeKitManager = StoreKitManager()
    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @EnvironmentObject var authService: AuthService
    @State private var sections: [CourseSection] = []
    @State private var unitsBySection: [UUID: [CourseUnit]] = [:]
    @State private var testsBySection: [UUID: [CourseTest]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSubscriptionSheet = false
    @State private var hasPassedGroundSchoolTest = false
    @State private var navigateToTest = false
    @State private var completedUnitIds: Set<UUID> = []
    @State private var completedUnitNumbers: Set<Int> = []
    @State private var passedTestIds: Set<UUID> = []
    @State private var courseTests: [CourseTest] = []
    
    /// Check if user has active subscription from any source (Apple or Stripe)
    var hasSubscription: Bool {
        entitlementManager.hasAcademyPass
    }
    
    // Get the first multiple choice test for this course (if any)
    var multipleChoiceTest: CourseTest? {
        courseTests.first { $0.testType == "multiple_choice" }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Course Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Render sections dynamically from database
                    ForEach(sections) { section in
                        DynamicSectionView(
                            section: section,
                            units: unitsBySection[section.id] ?? [],
                            tests: testsBySection[section.id] ?? [],
                            course: course,
                            hasSubscription: hasSubscription,
                            hasPassedTest: hasPassedGroundSchoolTest,
                            completedUnitIds: completedUnitIds,
                            completedUnitNumbers: completedUnitNumbers,
                            passedTestIds: passedTestIds,
                            onSubscribe: {
                                showSubscriptionSheet = true
                            },
                            onNavigateToTest: {
                                navigateToTest = true
                            }
                        )
                    }
                }
            }
            .refreshable {
                await refreshContent()
            }
        }
        .navigationTitle("Course Content")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Refresh completed units when returning from UnitDetailView
            if let currentUser = authService.currentUser {
                Task {
                    await loadCompletedUnits(pilotId: currentUser.id)
                    await loadPassedTests(pilotId: currentUser.id)
                }
            }
        }
        .task {
            await refreshContent()
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let currentUser = authService.currentUser,
                       let test = multipleChoiceTest {
                        MultipleChoiceTestView(
                            testId: test.id,
                            course: course,
                            pilotId: currentUser.id,
                            testName: test.testName,
                            passingScore: test.passingScore,
                            durationMinutes: 60 // Default duration, can be fetched from backend
                        )
                        .navigationBarBackButtonHidden(true)
                        .onDisappear {
                            Task {
                                if let user = authService.currentUser {
                                    do {
                                        hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: user.id, courseId: course.id)
                                    } catch {
                                        print("Error refreshing test status: \(error)")
                                    }
                                }
                            }
                        }
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToTest
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    /// Refreshes all course content including sections, units, subscription status, and progress
    private func refreshContent() async {
        print("🚀 [CourseContentView] Refreshing course content...")
        await loadSectionsAndUnits()
        await loadCourseTests()
        if let currentUser = authService.currentUser {
            print("👤 [CourseContentView] Current user ID: \(currentUser.id)")
            
            // Check ALL subscription sources (Apple + Stripe backend)
            _ = await storeKitManager.checkAllSubscriptions(pilotId: currentUser.id)
            print("📋 [CourseContentView] Subscription status: \(hasSubscription) (source: \(entitlementManager.subscriptionSourceDisplayName))")
            
            do {
                print("🔄 [CourseContentView] Checking Ground School Test status...")
                hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: currentUser.id, courseId: course.id)
                print("📋 [CourseContentView] Ground School Test passed: \(hasPassedGroundSchoolTest)")
            } catch {
                print("❌ [CourseContentView] Error checking test status: \(error)")
            }
            
            // Fetch completed unit IDs
            await loadCompletedUnits(pilotId: currentUser.id)
            
            // Fetch passed test IDs for prerequisite checking
            await loadPassedTests(pilotId: currentUser.id)
        }
    }
    
    private func loadCourseTests() async {
        do {
            courseTests = try await academyService.fetchCourseTests(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(courseTests.count) course tests")
        } catch {
            print("❌ [CourseContentView] Error loading course tests: \(error)")
        }
    }
    
    private func loadCompletedUnits(pilotId: UUID) async {
        do {
            let supabase = SupabaseClient.shared.client
            let response: [UnitCompletion] = try await supabase
                .from("unit_completions")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: course.id.uuidString)
                .execute()
                .value
            
            completedUnitIds = Set(response.map { $0.unitId })
            
            // Also load completed unit numbers for prerequisite checking
            let unitCompletionsWithNumbers = try await supabase
                .from("unit_completions")
                .select("*, course_units!inner(unit_number)")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: course.id.uuidString)
                .execute()
            
            let data = unitCompletionsWithNumbers.data
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var numbers: Set<Int> = []
                for item in jsonArray {
                    if let courseUnits = item["course_units"] as? [String: Any],
                       let unitNumber = courseUnits["unit_number"] as? Int {
                        numbers.insert(unitNumber)
                    }
                }
                completedUnitNumbers = numbers
            }
            
            print("✅ [CourseContentView] Loaded \(completedUnitIds.count) completed units, unit numbers: \(completedUnitNumbers.sorted())")
        } catch {
            print("❌ [CourseContentView] Error loading completed units: \(error)")
        }
    }
    
    private func loadPassedTests(pilotId: UUID) async {
        do {
            let supabase = SupabaseClient.shared.client
            let response = try await supabase
                .from("test_results")
                .select("test_id")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: course.id.uuidString)
                .eq("passed", value: true)
                .execute()
            
            let data = response.data
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var testIds: Set<UUID> = []
                for item in jsonArray {
                    if let testIdString = item["test_id"] as? String,
                       let testId = UUID(uuidString: testIdString) {
                        testIds.insert(testId)
                    }
                }
                passedTestIds = testIds
                print("✅ [CourseContentView] Loaded \(passedTestIds.count) passed tests")
            }
        } catch {
            print("❌ [CourseContentView] Error loading passed tests: \(error)")
        }
    }
    
    private func loadSectionsAndUnits() async {
        print("📚 [CourseContentView] Loading sections and units for course: \(course.title)")
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch sections from database
            let dbSections = try await academyService.fetchCourseSections(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(dbSections.count) sections from database")
            
            // Fetch all units for the course
            let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(allUnits.count) units")
            
            // Fetch all tests for the course
            let allTests = try await academyService.fetchCourseTests(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(allTests.count) tests")
            
            // Check if course has sections defined in database
            if dbSections.isEmpty && !allUnits.isEmpty {
                // FALLBACK: Course has no sections in database - create legacy sections
                print("⚠️ [CourseContentView] No sections found, using legacy fallback")
                let (fallbackSections, fallbackGrouped) = createLegacySections(from: allUnits)
                sections = fallbackSections
                unitsBySection = fallbackGrouped
                testsBySection = [:] // No tests in legacy sections
            } else {
                // Use database sections and group units
                sections = dbSections
                var groupedUnits: [UUID: [CourseUnit]] = [:]
                var groupedTests: [UUID: [CourseTest]] = [:]
                var unassignedUnits: [CourseUnit] = []
                
                // Group units by section
                for unit in allUnits {
                    if let sectionId = unit.sectionId {
                        if groupedUnits[sectionId] == nil {
                            groupedUnits[sectionId] = []
                        }
                        groupedUnits[sectionId]?.append(unit)
                    } else {
                        // Collect units without section_id
                        unassignedUnits.append(unit)
                    }
                }
                
                // Group tests by section
                for test in allTests {
                    if let sectionId = test.sectionId {
                        if groupedTests[sectionId] == nil {
                            groupedTests[sectionId] = []
                        }
                        groupedTests[sectionId]?.append(test)
                    }
                }
                
                // Handle unassigned units by placing them in appropriate legacy sections
                if !unassignedUnits.isEmpty {
                    print("⚠️ [CourseContentView] Found \(unassignedUnits.count) units without section_id, assigning to legacy sections")
                    assignUnassignedUnits(unassignedUnits, to: &groupedUnits, sections: sections)
                }
                
                unitsBySection = groupedUnits
                testsBySection = groupedTests
            }
            
            for section in sections {
                let unitCount = unitsBySection[section.id]?.count ?? 0
                let testCount = testsBySection[section.id]?.count ?? 0
                print("📊 [CourseContentView] Section '\(section.name)': \(unitCount) units, \(testCount) tests")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [CourseContentView] Error loading course content: \(error)")
        }
        
        isLoading = false
    }
    
    /// Creates legacy sections based on step_number and is_mandatory fields for courses without database sections
    private func createLegacySections(from units: [CourseUnit]) -> ([CourseSection], [UUID: [CourseUnit]]) {
        var sections: [LegacySection] = []
        var grouped: [UUID: [CourseUnit]] = [:]
        
        // Separate units by legacy fields
        let mandatoryUnits = units.filter { $0.isMandatory }
        let step1Units = units.filter { !$0.isMandatory && $0.stepNumber == 1 }
        let step2Units = units.filter { !$0.isMandatory && $0.stepNumber == 2 }
        let step3Units = units.filter { !$0.isMandatory && $0.stepNumber == 3 }
        let otherUnits = units.filter { !$0.isMandatory && ($0.stepNumber == nil || $0.stepNumber == 0 || $0.stepNumber! > 3) }
        
        // Create sections for non-empty groups
        if !mandatoryUnits.isEmpty {
            let section = LegacySection(name: "MANDATORY UNITS", displayOrder: 1, requiresSubscription: false, requiresTestPassed: false)
            sections.append(section)
            grouped[section.id] = mandatoryUnits.sorted { $0.orderIndex < $1.orderIndex }
        }
        
        if !step1Units.isEmpty {
            let section = LegacySection(name: "BASE PROGRAM", displayOrder: 2, requiresSubscription: false, requiresTestPassed: true)
            sections.append(section)
            grouped[section.id] = step1Units.sorted { $0.orderIndex < $1.orderIndex }
        }
        
        if !step2Units.isEmpty {
            let section = LegacySection(name: "EXTENSION COURSES", displayOrder: 3, requiresSubscription: true, requiresTestPassed: true)
            sections.append(section)
            grouped[section.id] = step2Units.sorted { $0.orderIndex < $1.orderIndex }
        }
        
        if !step3Units.isEmpty {
            let section = LegacySection(name: "FURTHER YOUR BASE TRAINING", displayOrder: 4, requiresSubscription: true, requiresTestPassed: true)
            sections.append(section)
            grouped[section.id] = step3Units.sorted { $0.orderIndex < $1.orderIndex }
        }
        
        if !otherUnits.isEmpty {
            let section = LegacySection(name: "COURSE CONTENT", displayOrder: sections.count + 1, requiresSubscription: false, requiresTestPassed: false)
            sections.append(section)
            grouped[section.id] = otherUnits.sorted { $0.orderIndex < $1.orderIndex }
        }
        
        // Convert to CourseSection format
        let courseSections = sections.sorted { $0.displayOrder < $1.displayOrder }.map { $0.toCourseSection(courseId: course.id) }
        return (courseSections, grouped)
    }
    
    /// Assigns units without section_id to appropriate sections based on legacy fields
    private func assignUnassignedUnits(_ units: [CourseUnit], to grouped: inout [UUID: [CourseUnit]], sections: [CourseSection]) {
        for unit in units {
            // Try to find matching section based on legacy fields
            var targetSectionId: UUID?
            
            if unit.isMandatory {
                // Find MANDATORY UNITS section
                targetSectionId = sections.first { $0.name.uppercased().contains("MANDATORY") }?.id
            } else if let stepNumber = unit.stepNumber {
                switch stepNumber {
                case 1:
                    targetSectionId = sections.first { $0.name.uppercased().contains("BASE PROGRAM") }?.id
                case 2:
                    targetSectionId = sections.first { $0.name.uppercased().contains("EXTENSION") }?.id
                case 3:
                    targetSectionId = sections.first { $0.name.uppercased().contains("FURTHER") }?.id
                default:
                    break
                }
            }
            
            // Fallback: assign to first available units section
            if targetSectionId == nil {
                targetSectionId = sections.first { $0.sectionType == "units" }?.id
            }
            
            if let sectionId = targetSectionId {
                if grouped[sectionId] == nil {
                    grouped[sectionId] = []
                }
                grouped[sectionId]?.append(unit)
                // Sort units by order_index after adding
                grouped[sectionId]?.sort { $0.orderIndex < $1.orderIndex }
            } else {
                print("⚠️ [CourseContentView] Could not assign unit '\(unit.title)' to any section")
            }
        }
    }
}

// MARK: - Legacy Section Helper (for courses without database sections)

private struct LegacySection {
    let id: UUID = UUID()
    let name: String
    let displayOrder: Int
    let requiresSubscription: Bool
    let requiresTestPassed: Bool
    
    func toCourseSection(courseId: UUID) -> CourseSection {
        return CourseSection(
            id: id,
            courseId: courseId,
            name: name,
            displayOrder: displayOrder,
            description: nil,
            sectionType: "units",
            requiresSubscription: requiresSubscription,
            requiresTestPassed: requiresTestPassed,
            prerequisiteSectionId: nil,
            isActive: true,
            examType: nil
        )
    }
}

// MARK: - Dynamic Section View (renders based on section type from database)

struct DynamicSectionView: View {
    let section: CourseSection
    let units: [CourseUnit]
    let tests: [CourseTest]
    let course: TrainingCourse
    let hasSubscription: Bool
    let hasPassedTest: Bool
    let completedUnitIds: Set<UUID>
    let completedUnitNumbers: Set<Int>
    let passedTestIds: Set<UUID>
    let onSubscribe: () -> Void
    let onNavigateToTest: () -> Void
    
    var isLocked: Bool {
        (section.requiresTestPassed && !hasPassedTest) ||
        (section.requiresSubscription && !hasSubscription)
    }
    
    var lockReason: String {
        let needsTest = section.requiresTestPassed && !hasPassedTest
        let needsSub = section.requiresSubscription && !hasSubscription
        
        if needsTest && needsSub {
            return "Pass Ground School Test & Subscribe to unlock"
        } else if needsTest {
            return "Complete Ground School Test to unlock"
        } else if needsSub {
            return "Subscribe to unlock"
        }
        return ""
    }
    
    var body: some View {
        return Group {
            switch section.sectionType {
            case "test", "exam":
                // Unified handling for test and exam sections
                // Display all tests associated with this section
                if !tests.isEmpty {
                    TestsSectionView(
                        section: section,
                        tests: tests,
                        course: course,
                        hasPassedTest: hasPassedTest,
                        passedTestIds: passedTestIds
                    )
                } else {
                    // Fallback to legacy behavior if no tests found
                    EmptyView()
                }
                
            case "recurrent":
                // Render recurrent training section
                RecurrentTrainingSectionContent(
                    sectionName: section.name,
                    hasPassedTest: hasPassedTest,
                    hasSubscription: hasSubscription,
                    onSubscribe: onSubscribe
                )
                
            default:
                // Render regular units section
                if !units.isEmpty {
                    DynamicUnitsSectionView(
                        section: section,
                        units: units,
                        course: course,
                        hasSubscription: hasSubscription,
                        hasPassedTest: hasPassedTest,
                        completedUnitIds: completedUnitIds,
                        completedUnitNumbers: completedUnitNumbers,
                        passedTestIds: passedTestIds,
                        onSubscribe: onSubscribe
                    )
                } else {
                    // Show a placeholder for empty sections
                    Text("Section '\(section.name)' has no units yet")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                }
            }
        }
    }
}

// MARK: - Tests Section View

struct TestsSectionView: View {
    let section: CourseSection
    let tests: [CourseTest]
    let course: TrainingCourse
    let hasPassedTest: Bool
    let passedTestIds: Set<UUID>
    @EnvironmentObject var authService: AuthService
    
    var isLocked: Bool {
        section.requiresTestPassed && !hasPassedTest
    }
    
    var lockReason: String {
        if isLocked {
            return "Complete Ground School Test to unlock"
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(tests.sorted(by: { $0.orderIndex < $1.orderIndex })) { test in
                    TestRow(
                        test: test,
                        course: course,
                        isLocked: isLocked,
                        lockReason: lockReason,
                        isPassed: passedTestIds.contains(test.id),
                        sectionDescription: section.description
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Test Row

struct TestRow: View {
    let test: CourseTest
    let course: TrainingCourse
    let isLocked: Bool
    let lockReason: String
    let isPassed: Bool
    let sectionDescription: String?
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if isLocked {
                // Locked test - show disabled card
                TestCardContent(
                    test: test,
                    sectionDescription: sectionDescription,
                    isLocked: true,
                    lockReason: lockReason,
                    isPassed: isPassed
                )
            } else {
                // Unlocked test - navigate based on test type
                if test.testType == "multiple_choice" {
                    // Multiple choice test - navigate to test view
                    if let currentUser = authService.currentUser {
                        NavigationLink(destination: MultipleChoiceTestView(
                            testId: test.id,
                            course: course,
                            pilotId: currentUser.id,
                            testName: test.testName,
                            passingScore: test.passingScore,
                            durationMinutes: 60
                        )) {
                            TestCardContent(
                                test: test,
                                sectionDescription: sectionDescription,
                                isLocked: false,
                                lockReason: "",
                                isPassed: isPassed
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else if test.testType == "oral" || test.testType == "practical" {
                    // Oral/practical exam - link to Test Center or exam intro
                    // Determine exam type based on test name
                    let examType = determineExamType(for: test)
                    if let examType = examType {
                        NavigationLink(destination: ExamIntroView(examType: examType)) {
                            TestCardContent(
                                test: test,
                                sectionDescription: sectionDescription,
                                isLocked: false,
                                lockReason: "",
                                isPassed: isPassed
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Unknown exam type, show card without navigation
                        TestCardContent(
                            test: test,
                            sectionDescription: sectionDescription,
                            isLocked: false,
                            lockReason: "",
                            isPassed: isPassed
                        )
                    }
                } else {
                    // Other test types - show card without navigation
                    TestCardContent(
                        test: test,
                        sectionDescription: sectionDescription,
                        isLocked: false,
                        lockReason: "",
                        isPassed: isPassed
                    )
                }
            }
        }
    }
    
    private func determineExamType(for test: CourseTest) -> ExamType? {
        let testNameLower = test.testName.lowercased()
        if testNameLower.contains("roc-a") || testNameLower.contains("radio") {
            return .rocA
        } else if testNameLower.contains("flight review") {
            return .flightReview
        }
        return nil
    }
}

// MARK: - Test Card Content

struct TestCardContent: View {
    let test: CourseTest
    let sectionDescription: String?
    let isLocked: Bool
    let lockReason: String
    let isPassed: Bool
    
    var testIcon: String {
        switch test.testType {
        case "multiple_choice":
            return "doc.text.fill"
        case "practical":
            return "airplane"
        case "oral":
            return "antenna.radiowaves.left.and.right"
        case "written":
            return "pencil.and.outline"
        default:
            return "checkmark.circle.fill"
        }
    }
    
    var testColor: Color {
        if isLocked {
            return .gray
        } else if isPassed {
            return .green
        } else {
            return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Test Icon
            ZStack {
                Circle()
                    .fill(testColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isLocked ? "lock.fill" : testIcon)
                    .foregroundColor(testColor)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(test.testName)
                        .font(.headline)
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    if isPassed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                
                if let description = test.testDescription ?? sectionDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                } else if test.testType == "oral" || test.testType == "practical" {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Schedule in Test Center")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else if test.testType == "multiple_choice" {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Start Test")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            if !isLocked {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Dynamic Units Section View

struct DynamicUnitsSectionView: View {
    let section: CourseSection
    let units: [CourseUnit]
    let course: TrainingCourse
    let hasSubscription: Bool
    let hasPassedTest: Bool
    let completedUnitIds: Set<UUID>
    let completedUnitNumbers: Set<Int>
    let passedTestIds: Set<UUID>
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    let (isLocked, lockReason, requiresAction) = getLockStatus(for: unit)
                    let isCompleted = completedUnitIds.contains(unit.id)
                    
                    if isLocked {
                        if requiresAction == .subscribe {
                            Button(action: onSubscribe) {
                                UnitRow(unit: unit, isLocked: true, lockReason: lockReason, isCompleted: false)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            UnitRow(unit: unit, isLocked: true, lockReason: lockReason, isCompleted: false)
                        }
                    } else {
                        NavigationLink(destination: UnitDetailView(unit: unit, course: course)) {
                            UnitRow(unit: unit, isLocked: false, isCompleted: isCompleted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Determines the lock status for a unit based on:
    /// 1. Unit-level prerequisites (prerequisite_units and prerequisite_tests)
    /// 2. Section-level requirements (requires_subscription and requires_test_passed)
    private func getLockStatus(for unit: CourseUnit) -> (isLocked: Bool, lockReason: String, requiresAction: LockAction) {
        var reasons: [String] = []
        var needsSubscription = false
        
        // Check unit-level prerequisite units
        if let prerequisiteUnits = unit.prerequisiteUnits, !prerequisiteUnits.isEmpty {
            let missingUnits = prerequisiteUnits.filter { !completedUnitNumbers.contains($0) }
            if !missingUnits.isEmpty {
                let unitList = missingUnits.sorted().map { "Unit \($0)" }.joined(separator: ", ")
                reasons.append("Complete \(unitList)")
            }
        }
        
        // Check unit-level prerequisite tests
        if let prerequisiteTests = unit.prerequisiteTests, !prerequisiteTests.isEmpty {
            let missingTests = prerequisiteTests.filter { !passedTestIds.contains($0) }
            if !missingTests.isEmpty {
                reasons.append("Pass required test(s)")
            }
        }
        
        // Check section-level requirements (fallback for legacy behavior)
        let needsSectionTest = section.requiresTestPassed && !hasPassedTest
        let needsSectionSubscription = section.requiresSubscription && !hasSubscription
        
        if needsSectionTest {
            reasons.append("Complete Ground School Test")
        }
        
        if needsSectionSubscription {
            needsSubscription = true
            reasons.append("Subscribe to Buzz Academy Pass")
        }
        
        // Determine if unit is locked and why
        if reasons.isEmpty {
            return (false, "", .none)
        }
        
        let lockReason = reasons.joined(separator: " & ")
        
        // Determine what action is required
        if needsSubscription && reasons.count == 1 {
            // Only subscription is needed
            return (true, lockReason, .subscribe)
        } else if needsSectionTest && !needsSubscription && reasons.count == 1 {
            // Only test is needed
            return (true, lockReason, .test)
        } else {
            // Multiple requirements or prerequisite units/tests needed
            return (true, lockReason, needsSubscription ? .subscribe : .none)
        }
    }
    
    private enum LockAction {
        case none
        case test
        case subscribe
    }
}

// MARK: - Unit Row

struct UnitRow: View {
    let unit: CourseUnit
    var isLocked: Bool = false
    var lockReason: String = "Subscribe to unlock"
    var isCompleted: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Unit Number Badge
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : (isCompleted ? Color.green.opacity(0.2) : Color.blue.opacity(0.2)))
                    .frame(width: 50, height: 50)
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.headline)
                } else if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                } else {
                    Text("\(unit.unitNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(unit.title)
                        .font(.headline)
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    if isLocked {
                        Text("🔒")
                            .font(.caption)
                    }
                }
                
                if let description = unit.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                } else if isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Completed")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(isLocked ? Color(.systemGray5) : (isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6)))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

// MARK: - Ground School Test Section Content

struct GroundSchoolTestSectionContent: View {
    var sectionName: String = "GROUND SCHOOL TEST"  // Default for backward compatibility
    let hasPassedTest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Test Icon
                    ZStack {
                        Circle()
                            .fill(hasPassedTest ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: hasPassedTest ? "checkmark.seal.fill" : "pencil.line")
                            .foregroundColor(hasPassedTest ? .green : .orange)
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ground School Test")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(hasPassedTest 
                             ? "You've passed the test! Continue to next section." 
                             : "Complete units 1-3, then take this test to continue.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        if hasPassedTest {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Passed")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Required to continue")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if !hasPassedTest {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding()
                .background(hasPassedTest ? Color.green.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Recurrent Training Section Content

struct RecurrentTrainingSectionContent: View {
    var sectionName: String = "RECURRENT TRAINING"  // Default for backward compatibility
    let hasPassedTest: Bool
    let hasSubscription: Bool
    let onSubscribe: () -> Void
    
    // Recurrent Training requires BOTH test passed AND subscription
    private var isLocked: Bool {
        !hasPassedTest || !hasSubscription
    }
    
    private var lockReason: String {
        if !hasPassedTest && !hasSubscription {
            return "Pass Ground School Test & Subscribe to unlock"
        } else if !hasPassedTest {
            return "Complete Ground School Test to unlock"
        } else if !hasSubscription {
            return "Subscribe to unlock"
        }
        return ""
    }
    
    private var isTappable: Bool {
        // Tappable if only subscription is missing (can subscribe)
        // Not tappable if test is missing (must take test first)
        !hasPassedTest ? false : !hasSubscription
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if isTappable {
                    // Tappable - can subscribe
                    Button(action: onSubscribe) {
                        RecurrentTrainingCardContent(
                            isLocked: isLocked,
                            lockReason: lockReason
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Not tappable - test required or already unlocked
                    RecurrentTrainingCardContent(
                        isLocked: isLocked,
                        lockReason: lockReason
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Recurrent Training Card Content

struct RecurrentTrainingCardContent: View {
    let isLocked: Bool
    let lockReason: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Recurrent Training Icon
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isLocked ? "lock.fill" : "arrow.clockwise.circle.fill")
                    .foregroundColor(isLocked ? .gray : .purple)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Part 107 Recurrent Training")
                    .font(.headline)
                    .foregroundColor(isLocked ? .secondary : .primary)
                
                Text("Comprehensive course material to help you pass the 2-year recurrent training requirement. Stay current with FAA Part 107 regulations and maintain your remote pilot certificate.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(isLocked ? Color(.systemGray5) : Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

// MARK: - Test Center Exam Section View

struct TestCenterExamSectionView: View {
    let section: CourseSection
    let hasPassedTest: Bool
    
    private var examType: ExamType? {
        guard let examTypeString = section.examType else { return nil }
        return ExamType(rawValue: examTypeString)
    }
    
    private var isLocked: Bool {
        section.requiresTestPassed && !hasPassedTest
    }
    
    private var lockReason: String {
        if isLocked {
            return "Complete Ground School Test to unlock"
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if let examType = examType {
                    if isLocked {
                        // Locked - show disabled card
                        TestCenterExamCardContent(
                            examType: examType,
                            sectionDescription: section.description,
                            isLocked: true,
                            lockReason: lockReason
                        )
                    } else {
                        // Unlocked - navigate to exam intro
                        NavigationLink(destination: ExamIntroView(examType: examType)) {
                            TestCenterExamCardContent(
                                examType: examType,
                                sectionDescription: section.description,
                                isLocked: false,
                                lockReason: ""
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Test Center Exam Card Content

struct TestCenterExamCardContent: View {
    let examType: ExamType
    let sectionDescription: String?
    let isLocked: Bool
    let lockReason: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Exam Icon
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : examType.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isLocked ? "lock.fill" : examType.icon)
                    .foregroundColor(isLocked ? .gray : examType.color)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(examType.displayName)
                    .font(.headline)
                    .foregroundColor(isLocked ? .secondary : .primary)
                
                Text(sectionDescription ?? ExamTypeConfig.defaultConfig(for: examType).shortDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Schedule in Test Center")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(isLocked ? Color(.systemGray5) : Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

