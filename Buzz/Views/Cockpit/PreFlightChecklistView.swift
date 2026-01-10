//
//  PreFlightChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/29/25.
//

import SwiftUI
import Combine

struct PreFlightChecklistView: View {
    @ObservedObject var checklistService: ChecklistService
    let booking: Booking
    
    // Section expansion states (all collapsed by default)
    @State private var isAviationRestrictionsExpanded = false
    @State private var isGroundBasedRestrictionsExpanded = false
    @State private var isAircraftCheckExpanded = false
    @State private var isCrewReadinessExpanded = false
    @State private var isVisualObserverResponsibilitiesExpanded = false
    @State private var isPotentialHazardsExpanded = false
    @State private var isGeneralRequirementsExpanded = false
    @State private var isTakeoffProcedureExpanded = false
    @State private var isLandingProcedureExpanded = false
    @State private var isSFOCRequiredExpanded = false
    
    // Checklist item states - using StateObject to persist across view recreations
    @StateObject private var checklistState = PreFlightChecklistState()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section Title with Collapse All Button
                HStack {
                    Text("Pre-Flight Checklist")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: collapseAllSections) {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Aviation Restrictions and Hazards Section
                CollapsibleSection(
                    title: "AVIATION RESTRICTIONS AND HAZARDS",
                    isExpanded: $isAviationRestrictionsExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "If flight will be nearer than 5.6 km (3 NM) away from airports, or 1.9 km (1 NM) away from helicopters, call airport operator in advance to understand established UAS procedures at that aerodrome and to secure permission. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check FAA Flight Supplements and Water Aerodrome Supplements."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If flight will be in Controlled Airspace or Restricted Airspace, confirm that drone is accepted for Controlled Airspace operation. Secure permission from airspace authority and understand procedures. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check Designated Airspace Handbook."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If flight will be nearer than 5.6 km (3 NM) from a military aerodrome, ensure an SFOC has been approved. Secure permission from airspace authority and understand procedures. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check Designated Airspace Handbook."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Locate other aerodromes in flight area and ensure flight stays out of established flight patterns of those aerodromes. Check app for safe flying zones. Check LAANC and IACRA web pages. Check FAA Flight Supplements and Water Aerodrome Supplements."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure no impacting temporary aviation restrictions are in effect. Check LAANC and the FAA NOTAM site."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check visually and audibly for nearby low altitude air operations such as helicopters, seaplanes, hot air balloons, and ultra-light aircraft."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check suitability of current weather and weather forecast for the duration of the operation (wind, rain, snow, fog, temperature)."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Ground-Based Flight Restrictions & Proximity to People Section
                CollapsibleSection(
                    title: "GROUND-BASED FLIGHT RESTRICTIONS & PROXIMITY TO PEOPLE",
                    isExpanded: $isGroundBasedRestrictionsExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "If operation will include flying between 5m and 30m (horizontally) away from bystanders, ensure that drone is approved for flying near people. Check manual."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If operation will include flying closer than 5m horizontally from bystanders, ensure that drone is approved for flying over people. Check manual."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure crew and other involved parties are aware of flight and stand clear."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If operation involves flying at an advertised event such as parades, sporting events, or outdoor concerts, ensure an SFOC has been approved."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check for and plan to stay clear of land-based flight restrictions, including police activities (e.g. traffic accidents), forest fires, or other natural disasters."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Take note of potential obstacles such as buildings, wires, trees, cell towers, wind turbines. Check maps for marked obstacles."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Aircraft Check Section
                CollapsibleSection(
                    title: "AIRCRAFT CHECK",
                    isExpanded: $isAircraftCheckExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Check that drone is registered and registration number is on the drone."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If operation involves flying in controlled airspace, near or over people, confirm drone model is approved on FAA list for such operations."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check for damage, cracks, or other signs of potential failure."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check propellers for cracks, deformation, or other wear."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure drone and control unit batteries are fully charged."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check that propellers, propeller guards, and other removable items are secure, and items such as gimbal guards and lens covers are removed."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure micro-SD card is installed for camera recording."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure launch site is suitable for take-off (level, clear of debris, nothing to interfere with camera gimbal, pad in place if required for mud or snow)."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Crew Readiness Section
                CollapsibleSection(
                    title: "CREW READINESS",
                    isExpanded: $isCrewReadinessExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Confirm that pilot is certified for Advanced Operations (or is at least 16 years old and under direct supervision of a certified pilot)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Confirm that all flight crew members are fit to perform: No alcohol consumption within prior 12 hours. Not under the influence of any drug that may impair safety. Not suffering from fatigue."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure all flight crew members (eg. Visual Observer) understand their roles, means of communicating with the pilot, and emergency procedures."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure any other people involved in the operation understand to stay clear during take off and landing, and not to interfere with the pilot and crew during the operation."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Confirm crew is aware of take-off plan, landing plan and back-up landing plan."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure any special attributes of the flight are properly addressed (eg FPV googles, night flying)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure flight log is available to record flight."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Visual Observer Responsibilities Section
                CollapsibleSection(
                    title: "VISUAL OBSERVER RESPONSIBILITIES",
                    isExpanded: $isVisualObserverResponsibilitiesExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "A Visual Observer (VO) is a trained UAS crew member who assists the Pilot in Command (PIC) in ensuring the safe conduct of a flight. The VO serves as a second set of eyes to support the PIC to maintain VLOS to the RPAS and to add in Detect and Avoid Functions."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO shall systematically scan the area of flight and surrounding area for potential hazards to the flight, including conflicting air traffic, hazards to aviation safety or hazards to persons on the ground, and immediately communicate such hazards to the PIC (see list of hazards below)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO shall maintain Visual Line of Sight (VLOS) with the UAS at all times, and shall immediately inform the PIC if VLOS is lost."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If the VO needs to break VLOS (for example, to scan an area well away from the UAS), the VO must pass VLOS responsibilities to the PIC or other crew member for the duration of this task."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO shall be familiar with the mission, such that potential hazards can be anticipated and where applicable, contingency plans can be developed in concert with the PIC (see list of hazards below)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO should be aware of the limits associated with potential hazards (eg, maximum wind speed for the UAS) in order to appropriately alert the PIC."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Potential Hazards Section
                CollapsibleSection(
                    title: "POTENTIAL HAZARDS THE VO SHOULD BE AWARE OF, AND KNOW THE LIMITS FOR",
                    isExpanded: $isPotentialHazardsExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Airspace hazards: manned aircraft, aerodromes in the vicinity, air traffic patterns, airspace types, applicable NOTAMs, potential birds/wildlife."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ground hazards: location and height of buildings, towers, structures, wires/cables, trees, terrain features."
                        )
                        
                        PreFlightChecklistItem(
                            text: "People hazards: advertised events, locations and potential paths of bystanders, other UAS operators."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Environmental hazards: weather conditions and forecast (particularly wind, temperature, and precipitation), Kp-Index."
                        )
                    }
                }
                .padding(.horizontal)
                
                // General Requirements Section
                CollapsibleSection(
                    title: "GENERAL REQUIREMENTS",
                    isExpanded: $isGeneralRequirementsExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "The VO must always comply with instructions from the PIC during flight time."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO must be able to communicate effectively and in a timely manner with the PIC, either directly or via an agreed-upon, reliable communications device."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO must be fit to perform their duty, including not ingesting alcohol or drugs within 12 hours of the flight, and not being subject to fatigue."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO must be able to perform their duties with unaided sight, without instruments such as binoculars."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO must not operate a moving vehicle, vessel or aircraft while performing their in-flight VO duties."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO must be familiar with UAS regulations applicable to the type of operation being performed."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO shall perform VO duties for only one UAS at a time (exceptions: see SFOC)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "The VO may aid in other duties, per the PIC's instructions, as long as such tasks do not interfere with their ability to perform their in-flight VO duties. Examples of other duties include pre-flight site assessment, checklist read-outs, ground crew supervision, or crowd control."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Take-Off and Launch Procedure Section
                CollapsibleSection(
                    title: "TAKE-OFF AND LAUNCH PROCEDURE",
                    isExpanded: $isTakeoffProcedureExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Confirm completion of pre-flight checklist."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Record beginning of flight log information."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Assemble control unit, display, and related gear."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Prepare drone for launch."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Activate control unit and display device."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Launch drone control app on phone."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Activate drone."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Initiate control unit and drone communication connection, and confirm proper linkage."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure all control switches are correctly set for operation."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check that firmware load for entire system are up to date and consistent."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check that compass, IMU, and gimbal calibration are okay."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure Return-to-Home parameters are correct for current operation (correct mode, sufficient altitude)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure sufficient GPS satellites are connected (minimum 7)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Perform final weather check (temperature, imminent storms, wind direction & speed)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Signal to crew and bystanders to stand clear for take-off (particularly ensure no one is downwind from drone in case of take-off drift)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Start camera recording."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Announce take-off and stand clear."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Activate take-off controls."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Allow drone to hover at low altitude to confirm stability before further flight."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Test controls to ensure full directional control."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Landing Procedure Section
                CollapsibleSection(
                    title: "LANDING PROCEDURE",
                    isExpanded: $isLandingProcedureExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Alert crew and bystanders of approaching aircraft."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure landing site is clear of debris and is suitable for landing."
                        )
                        
                        PreFlightChecklistItem(
                            text: "When drone is approximately 10m away, rotate drone to face away (to allow natural flight control movements)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure all crew and involved people are clear of landing site."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure all bystanders are 30m away from landing site."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Land drone."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Turn off motors and camera."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Retrieve drone and inspect for damage."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Disassemble as required, apply gimbal guard and lens cover, stow gear."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Record flight in flight log."
                        )
                    }
                }
                .padding(.horizontal)
                
                // Operations Requiring an SFOC Section
                CollapsibleSection(
                    title: "OPERATIONS REQUIRING AN SFOC",
                    isExpanded: $isSFOCRequiredExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "Any drone weighing more than 25kg."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Flying beyond Visual Line of Sight (VLOS)."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Pilot who is not a US citizen or permanent resident of the United States."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Flying higher than normal maximum altitudes unless authorized by Air Traffic Control."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Operating more than 5 UAS from one control station."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Flying at a special aviation event or at an advertised event."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Carrying hazardous payload."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Flying within 3 nautical miles of a military aerodrome."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Any other operation that the FAA decides requires an SFOC."
                        )
                    }
                }
                .padding(.horizontal)
                
                if let error = checklistService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
        }
        .environmentObject(checklistState)
    }
    
    private func collapseAllSections() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAviationRestrictionsExpanded = false
            isGroundBasedRestrictionsExpanded = false
            isAircraftCheckExpanded = false
            isCrewReadinessExpanded = false
            isVisualObserverResponsibilitiesExpanded = false
            isPotentialHazardsExpanded = false
            isGeneralRequirementsExpanded = false
            isTakeoffProcedureExpanded = false
            isLandingProcedureExpanded = false
            isSFOCRequiredExpanded = false
        }
    }
}

// MARK: - Collapsible Section

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header (Tappable)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(isExpanded ? 12 : 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content (Collapsible)
            if isExpanded {
                VStack(spacing: 12) {
                    content()
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Checklist State Manager
// ObservableObject to persist checked states across view recreations

class PreFlightChecklistState: ObservableObject {
    @Published var checkedItems: Set<String> = []
    private let instanceId = UUID().uuidString.prefix(8)
    
    init() {
        print("🔍 PREFLIGHT_STATE[\(instanceId)]: PreFlightChecklistState initialized")
    }
    
    deinit {
        print("🔍 PREFLIGHT_STATE[\(instanceId)]: PreFlightChecklistState deinitialized")
    }
    
    func isChecked(_ itemId: String) -> Bool {
        checkedItems.contains(itemId)
    }
    
    func toggle(_ itemId: String) {
        if checkedItems.contains(itemId) {
            checkedItems.remove(itemId)
            print("🔍 PREFLIGHT_STATE[\(instanceId)]: Unchecked item: \(itemId)")
        } else {
            checkedItems.insert(itemId)
            print("🔍 PREFLIGHT_STATE[\(instanceId)]: Checked item: \(itemId)")
        }
        print("🔍 PREFLIGHT_STATE[\(instanceId)]: Total checked items: \(checkedItems.count)")
    }
}

// MARK: - Pre-Flight Checklist Item

struct PreFlightChecklistItem: View {
    let text: String
    @EnvironmentObject var checklistState: PreFlightChecklistState
    
    // Generate a stable ID from the text (first 50 chars is enough for uniqueness)
    private var itemId: String {
        String(text.prefix(50))
    }
    
    private var isChecked: Bool {
        checklistState.isChecked(itemId)
    }
    
    var body: some View {
        Button(action: {
            checklistState.toggle(itemId)
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .secondary)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 2)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
    let isComplete: Bool
    let title: String
    let subtitle: String?
    var isLink: Bool = false
    var instructions: [String]?
    var linkURL: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Instructions (if provided)
                if let instructions = instructions {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { _, instruction in
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Link URL (if provided)
                if let linkURL = linkURL {
                    Text(linkURL)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                
                // Subtitle (if provided and no instructions)
                if let subtitle = subtitle, instructions == nil {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isLink ? .blue : .secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLink {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
