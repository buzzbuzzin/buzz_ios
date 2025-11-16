-- Ground School Test - All 70 Questions
-- Generated from ground_school_exam_questions.csv
-- Run this AFTER you've run create_course_tests_system.sql

UPDATE course_tests
SET questions = $$
{
    "questions": [
        {
            "id": 1,
            "question": "A small UA causes an accident and your crew member loses consciousness. When do you report the accident?",
            "options": [
                "No accidents need to be reported.",
                "When requested by the UA owner.",
                "Within 10 days of the accident."
            ],
            "correctAnswer": 2
        },
        {
            "id": 2,
            "question": "Under what condition would a small UA not have to be registered before it is operated in the United States?",
            "options": [
                "When the aircraft weighs less than .55 pounds on takeoff, including everything that is on-board or attached to the aircraft.",
                "When the aircraft has a takeoff weight that is more than .55 pounds, but less than 55 pounds, not including fuel and necessary attachments.",
                "All small UAS need to be registered regardless of the weight of the aircraft before, during, or after the flight."
            ],
            "correctAnswer": 0
        },
        {
            "id": 3,
            "question": "According to 14 CFR part 48, when must a person register a small UA with the Federal Aviation Administration?",
            "options": [
                "All civilian small UAS weighing greater than .55 pounds must be registered regardless of its intended use.",
                "When the small UA is used for any purpose other than as a model aircraft.",
                "Only when the operator will be paid for commercial services."
            ],
            "correctAnswer": 0
        },
        {
            "id": 4,
            "question": "According to 14 CFR part 48, when would a small UA owner not be permitted to register it?",
            "options": [
                "The owner is less than 13 years of age.",
                "All persons must register their small UA.",
                "If the owner does not have a valid United States driver's license."
            ],
            "correctAnswer": 0
        },
        {
            "id": 5,
            "question": "Where must a small unmanned aircraft's serial number be listed when using either standard remote identification or a broadcast module?",
            "options": [
                "The aircraft's Document of Compliance.",
                "The manufacturer's Method of Compliance.",
                "The Certificate of Aircraft Registration."
            ],
            "correctAnswer": 2
        },
        {
            "id": 6,
            "question": "A small UA must be operated in a manner which",
            "options": [
                "does not endanger the life or property of another.",
                "requires more than one visual observer.",
                "never exceeds 200 feet AGL"
            ],
            "correctAnswer": 0
        },
        {
            "id": 7,
            "question": "You plan to release golf balls from your small UA at an altitude of 100 feet AGL. You must ensure the objects being dropped will",
            "options": [
                "not create an undue hazard to persons or property.",
                "land within 10 feet of the expected landing zone.",
                "not cause property damage in excess of $300."
            ],
            "correctAnswer": 0
        },
        {
            "id": 8,
            "question": "After having dinner and wine, your client asks you to go outside to demonstrate the small UAs capabilities. You must",
            "options": [
                "pass a self-administered sobriety test before operating a small UA.",
                "not operate a small UA within 8 hours of consuming any alcoholic beverage.",
                "ensure that your visual observer has not consumed any alcoholic beverage in the previous 12 hours."
            ],
            "correctAnswer": 1
        },
        {
            "id": 9,
            "question": "According to 14 CFR part 107, what is required to operate a small UA within 30 minutes after official sunset?",
            "options": [
                "Use of anti-collision lights.",
                "Must be operated in a rural area.",
                "Use of a transponder."
            ],
            "correctAnswer": 0
        },
        {
            "id": 10,
            "question": "During a flight of your small UA, you observe a hot air balloon entering the area. You should",
            "options": [
                "yield the right-of-way to the hot air balloon.",
                "ensure the UA passes below, above, or ahead of the balloon.",
                "expect the hot air balloon to climb above your altitude."
            ],
            "correctAnswer": 0
        },
        {
            "id": 11,
            "question": "Prior authorization required for operation in certain airspace. According to 14 CFR part 107, how may a remote pilot operate an unmanned aircraft in class C airspace?",
            "options": [
                "The remote pilot must have prior authorization from the Air Traffic Control (ATC) facility having jurisdiction over that airspace.",
                "The remote pilot must monitor the Air Traffic Control (ATC) frequency from launch to recovery.",
                "The remote pilot must contact the Air Traffic Control (ATC) facility after launching the unmanned aircraft."
            ],
            "correctAnswer": 0
        },
        {
            "id": 12,
            "question": "(Refer to FAA-CT-8080-2H.) You have been hired to use your small UAS to inspect the railroad tracks from Blencoe (SE of Sioux City) to Onawa. Will ATC authorization be required?",
            "options": [
                "Yes, Onawa is in Class D airspace that is designated for an airport.",
                "No, your entire flight is in Class G airspace.",
                "Yes, you must contact the Onawa control tower to operate within 5 miles of the airport."
            ],
            "correctAnswer": 1
        },
        {
            "id": 13,
            "question": "Preflight familiarization, inspection, and actions for aircraft operations. According to 14 CFR part 107, who is responsible for determining the performance of a small unmanned aircraft?",
            "options": [
                "Remote pilot-in-command.",
                "Manufacturer.",
                "Owner or operator."
            ],
            "correctAnswer": 0
        },
        {
            "id": 14,
            "question": "According to 14 CFR part 107, what is the maximum groundspeed for a small UA?",
            "options": [
                "87 knots.",
                "87 mph.",
                "100 knots."
            ],
            "correctAnswer": 0
        },
        {
            "id": 15,
            "question": "(Refer to FAA-CT-8080-2H.) You have been contracted to inspect towers located approximately 4NM southwest of the Sioux Gateway (SUX) airport operating an unmanned aircraft. What is the maximum altitude above ground level (AGL) that you are authorized to operate over the top of the towers?",
            "options": [
                "400 Feet AGL.",
                "402 feet AGL.",
                "802 feet AGL."
            ],
            "correctAnswer": 2
        },
        {
            "id": 16,
            "question": "Upon request by the FAA, the remote pilot-in-command must provide",
            "options": [
                "a logbook documenting small UA landing currency.",
                "a remote pilot certificate with a small UAS rating.",
                "any employer issued photo identification."
            ],
            "correctAnswer": 1
        },
        {
            "id": 17,
            "question": "When may a remote pilot reduce the intensity of an aircraft's lights during a night flight?",
            "options": [
                "At no time may the lights of an sUAS be reduced in intensity at night.",
                "When a manned aircraft is in the vicinity of the sUAS.",
                "When it is in the interest of safety to dim the aircraft's lights."
            ],
            "correctAnswer": 2
        },
        {
            "id": 18,
            "question": "The refusal of a remote PIC to submit to a blood alcohol test when requested by a law enforcement officer",
            "options": [
                "is grounds for suspension of revocation of their remote pilot certificate.",
                "can be delayed for a period up to 8 hours after the request.",
                "has no consequences to the remote pilot certificate."
            ],
            "correctAnswer": 0
        },
        {
            "id": 19,
            "question": "To conduct Category 1 operations, a remote pilot in command must use a small unmanned aircraft that weighs",
            "options": [
                "0.55 pounds or less.",
                "0.65 pounds or less.",
                "0.75 pounds or less."
            ],
            "correctAnswer": 0
        },
        {
            "id": 20,
            "question": "Which Category of small unmanned aircraft must have an airworthiness certificate issued by the FAA?",
            "options": [
                "4",
                "3",
                "2"
            ],
            "correctAnswer": 0
        },
        {
            "id": 21,
            "question": "What must a person, who is manipulating the controls of a small unmanned aircraft, do if the standard remote identification fails during a flight?",
            "options": [
                "Land the aircraft as soon as practicable.",
                "Notify the nearest FAA Air Traffic facility.",
                "Activate the aircraft's navigation lights."
            ],
            "correctAnswer": 0
        },
        {
            "id": 22,
            "question": "(Refer to FAA-CT-8080-2H.) The floor of Class B airspace at Dallas Executive (RBD) is",
            "options": [
                "at the surface.",
                "3,000 feet MSL.",
                "3,100 feet MSL."
            ],
            "correctAnswer": 1
        },
        {
            "id": 23,
            "question": "(Refer to FAA-CT-8080-2H) What is the floor of the Savannah Class C airspace at the shelf area (outer circle)?",
            "options": [
                "1,300 feet AGL.",
                "1,300 feet MSL.",
                "1,700 feet MSL."
            ],
            "correctAnswer": 1
        },
        {
            "id": 24,
            "question": "According to 14 CFR part 107 the remote pilot in command (PIC) of a small unmanned aircraft planning to operate within Class C airspace",
            "options": [
                "must use a visual observer.",
                "is required to file a flight plan.",
                "is required to receive ATC authorization."
            ],
            "correctAnswer": 2
        },
        {
            "id": 25,
            "question": "(Refer to FAA-CT-8080-2H) The Fentress NALF Airport (NFE) is in what type of airspace?",
            "options": [
                "Class C.",
                "Class E.",
                "Class G."
            ],
            "correctAnswer": 1
        },
        {
            "id": 26,
            "question": "(Prohibited, restricted, warning, military operations, alert, and controlled firing.) (Refer to FAA-CT-8080-2H.) The chart shows a gray line with \"VR1667, VR1617, VR1638, and VR1668.\" Could this area present a hazard to the operations of a small UA?",
            "options": [
                "No, all operations will be above 400 feet.",
                "Yes, this is a Military Training Route from 1,500 feet AGL.",
                "Yes, the defined route provides traffic separation to manned aircraft."
            ],
            "correctAnswer": 1
        },
        {
            "id": 27,
            "question": "(Refer to FAA-CT-8080-2H.) During preflight planning, you plan to operate in R-2305. Where would you find additional information regarding this airspace?",
            "options": [
                "In the Aeronautical Information Manual.",
                "In the Charts Supplements U.S.",
                "In the Special Use Airspace area of the chart."
            ],
            "correctAnswer": 1
        },
        {
            "id": 28,
            "question": "(Prohibited, restricted, warning, military operations, alert, and controlled firing.) (Refer to FAA-CT-8080-2H.) You have been hired by a farmer to use your small UA to inspect his crops. The area that you are to survey is in the Devil's Lake West MOA, east of area 2. How would you find out if the MOA is active?",
            "options": [
                "Refer to the legend and call Flight Service.",
                "This information is available in the Small UAS database.",
                "In the Military Operations Directory."
            ],
            "correctAnswer": 0
        },
        {
            "id": 29,
            "question": "Your surveying company is a title sponsor for a race team at the Indianapolis 500. To promote your new aerial surveying department, you decide to video part of the race using a small UA. The FAA has issued a Temporary Flight Restriction (TFR) for the race in the area you plan to fly. In this situation",
            "options": [
                "you may fly your drone in the TFR since your company is sponsoring a team at the race.",
                "the TFR applies to all aircraft; you may not fly in the area without a Certificate of Waiver or Authorization.",
                "flying your drone is allowed if you notify all non-participating people of the closed course UA operation."
            ],
            "correctAnswer": 1
        },
        {
            "id": 30,
            "question": "(Refer to FAA-CT-8080-2H.) What is the required flight visibility for a remote pilot operating an unmanned aircraft near the Plantation Airport (JYL)?",
            "options": [
                "5 statute miles.",
                "1 statute mile.",
                "3 statute miles."
            ],
            "correctAnswer": 2
        },
        {
            "id": 31,
            "question": "(Refer to FAA-CT-8080-2H.) Why would the small flag at Lake Drummond of the sectional chart be important to a remote pilot?",
            "options": [
                "This is a VFR check point for manned aircraft, and a higher volume of air traffic should be expected there.",
                "This is a GPS check point that can be used by both manned and remote pilots for orientation.",
                "This indicates that there will be a large obstruction depicted on the next printing of the chart."
            ],
            "correctAnswer": 0
        },
        {
            "id": 32,
            "question": "The NOTAM system including how to obtain an established NOTAM through Flight Service. (Refer to FAA-CT-8080-2H.) How would a remote PIC \"CHECK NOTAMS\" as noted in the CAUTION box regarding the unmarked balloon?",
            "options": [
                "By utilizing the B4UFLY mobile application.",
                "By contacting the FAA district office.",
                "By obtaining a briefing via an online source such as: 1800WXBrief.com."
            ],
            "correctAnswer": 2
        },
        {
            "id": 33,
            "question": "Aviation routine weather reports (METAR). (Refer to FAA-CT-8080-2H.) What are the current conditions for Chicago Midway Airport (KMDW)? [METAR KLAX 121852Z 25004KT 6SM BR SCT007 SCT250 16/15 A2991 SPECI KMDW 121856Z 32005KT 1 1/2SM RA OVC007 17/16 A2980 RMK RAB35]",
            "options": [
                "Sky 700 feet overcast, visibility 1-1/2SM, rain.",
                "Sky 7000 feet overcast, visibility 1-1/2SM, heavy rain.",
                "Sky 700 feet overcast, visibility 11, occasionally 2SM, with rain."
            ],
            "correctAnswer": 0
        },
        {
            "id": 34,
            "question": "Aviation routine weather reports (METAR). (Refer to FAA-CT-8080-2H.) The wind direction and velocity at KJFK is from [SPECI KJFK 121853Z 18004KT 1/2SM FG R04/2200 OVC005 20/18 A3006]",
            "options": [
                "180° true at 4 knots.",
                "180° magnetic at 4 knots.",
                "040° true at 18 knots."
            ],
            "correctAnswer": 0
        },
        {
            "id": 35,
            "question": "What effect does high density altitude have on the efficiency of a UA propeller?",
            "options": [
                "Propeller efficiency is increased.",
                "Propeller efficiency is decreased.",
                "Density altitude does not affect propeller efficiency."
            ],
            "correctAnswer": 1
        },
        {
            "id": 36,
            "question": "Atmospheric stability, pressure, and temperature. What are the characteristics of stable air?",
            "options": [
                "Good visibility and steady precipitation.",
                "Poor visibility and steady precipitation.",
                "Poor visibility and intermittent precipitation."
            ],
            "correctAnswer": 1
        },
        {
            "id": 37,
            "question": "What are characteristics of a moist, unstable air mass?",
            "options": [
                "Turbulence and showery precipitation.",
                "Poor visibility and smooth air.",
                "Haze and smoke."
            ],
            "correctAnswer": 0
        },
        {
            "id": 38,
            "question": "You have received an outlook briefing from flight service through 1800wxbrief.com. The briefing indicates you can expect a low-level temperature inversion with high relative humidity. What weather conditions would you expect?",
            "options": [
                "Smooth air, poor visibility, fog, haze, or low clouds.",
                "Light wind shear, poor visibility, haze, and light rain.",
                "Turbulent air, poor visibility, fog, low stratus type clouds, and showery precipitation."
            ],
            "correctAnswer": 0
        },
        {
            "id": 39,
            "question": "To ensure that the unmanned aircraft center of gravity (CG) limits are not exceeded, follow the aircraft loading instructions specified in the",
            "options": [
                "Pilot's Operating Handbook or UAS Flight Manual.",
                "Aeronautical Information Manual (AIM).",
                "Aircraft Weight and Balance Handbook."
            ],
            "correctAnswer": 0
        },
        {
            "id": 40,
            "question": "A stall occurs when the smooth airflow over the unmanned airplane wing is disrupted, and the lift degenerates rapidly. This is caused when the wing",
            "options": [
                "exceeds the maximum speed.",
                "exceeds maximum allowable operating weight.",
                "exceeds its critical angle of attack."
            ],
            "correctAnswer": 2
        },
        {
            "id": 41,
            "question": "The importance and use of performance data to predict the effect on the aircraft's performance of an sUAS. When operating an unmanned airplane, the remote pilot should consider that the load factor on the wings may be increased anytime",
            "options": [
                "the CG is shifted rearward to the aft CG limit.",
                "the airplane is subjected to maneuvers other than straight and level flight.",
                "the gross weight is reduced."
            ],
            "correctAnswer": 1
        },
        {
            "id": 42,
            "question": "(Refer to FAA-CT-8080-2H.) If an unmanned airplane weighs 33 pounds, what approximate weight would the airplane structure be required to support during a 30° banked turn while maintaining altitude?",
            "options": [
                "34 pounds.",
                "47 pounds.",
                "38 pounds."
            ],
            "correctAnswer": 2
        },
        {
            "id": 43,
            "question": "(Refer to FAA-CT-8080-2H.) While monitoring the Cooperstown CTAF you hear an aircraft announce that they are midfield left downwind to RWY 13. Where would the aircraft be relative to the runway?",
            "options": [
                "The aircraft is East.",
                "The aircraft is South.",
                "The aircraft is West."
            ],
            "correctAnswer": 0
        },
        {
            "id": 44,
            "question": "(Refer to FAA-CT-8080-2H.) After receiving authorization from ATC to operate a small UA near Minot International airport (MOT) while the control tower is operational, which radio communication frequency could be used to monitor manned aircraft and ATC communications?",
            "options": [
                "UNICOM 122.95",
                "ASOS 118.725.",
                "CT-118.2."
            ],
            "correctAnswer": 2
        },
        {
            "id": 45,
            "question": "(Refer to FAA-CT-8080-2H.) What airport is located approximately 47 (degrees) 40 (minutes) N latitude and 101 (degrees) 26 (minutes) W longitude?",
            "options": [
                "Mercer County Regional Airport.",
                "Semshenko Airport.",
                "Garrison Airport."
            ],
            "correctAnswer": 2
        },
        {
            "id": 46,
            "question": "(Refer to FAA-CT-8080-2H.) At Coeur D'Alene which frequency should be used as a Common Traffic Advisory Frequency (CTAF) to monitor airport traffic?",
            "options": [
                "122.05 MHz.",
                "135.075 MHz.",
                "122.8 MHz."
            ],
            "correctAnswer": 2
        },
        {
            "id": 47,
            "question": "(Refer to FAA-CT-8080-2H.) A small UA is being launched 2 NM northeast of the town of Hertford. What is the height of the highest obstacle?",
            "options": [
                "399 feet MSL.",
                "500 feet MSL.",
                "500 feet AGL."
            ],
            "correctAnswer": 2
        },
        {
            "id": 48,
            "question": "(Refer to FAA-CT-8080-2H.) You have been hired to inspect the tower under construction at 46.9N and 98.6W, near Jamestown Regional (JMS). What must you receive prior to flying your unmanned aircraft in this area?",
            "options": [
                "Authorization from the military.",
                "Authorization from ATC.",
                "Authorization from the National Park Service."
            ],
            "correctAnswer": 1
        },
        {
            "id": 49,
            "question": "(Refer to FAA-CT-8080-2H, and Legend 1.) For information about the parachute operations at Tri-County Airport, refer to",
            "options": [
                "notes on the border of the chart.",
                "Chart Supplements U.S.",
                "the Notices to Airmen (NOTAM) publication."
            ],
            "correctAnswer": 1
        },
        {
            "id": 50,
            "question": "(Refer to FAA-CT-8080-2H.) What class of airspace is associated with SIOUX GATEWAY/COL DAY (SUX) Airport?",
            "options": [
                "Class B airspace.",
                "Class C airspace.",
                "Class D airspace."
            ],
            "correctAnswer": 2
        },
        {
            "id": 51,
            "question": "(Refer to FAA-CT-8080-2H.) What type of airport is Card Airport?",
            "options": [
                "Public towered.",
                "Public non-towered.",
                "Private non-towered."
            ],
            "correctAnswer": 2
        },
        {
            "id": 52,
            "question": "(Refer to FAA-CT-8080-2H.) With ATC authorization, you are operating your small unmanned aircraft approximately 4 SM southeast of Elizabeth City Regional Airport (ECG). What hazard is indicated to be in that area?",
            "options": [
                "High density military operations in the vicinity.",
                "Unmarked balloon on a cable up to 3,008 feet AGL.",
                "Unmarked balloon on a cable up to 3,008 feet MSL."
            ],
            "correctAnswer": 2
        },
        {
            "id": 53,
            "question": "(Refer to FAA-CT-8080-2H, Figure 26.) What does the line of latitude at area 4 measure?",
            "options": [
                "The degrees of latitude east and west of the Prime Meridian.",
                "The degrees of latitude north and south from the equator.",
                "The degrees of latitude east and west of the line that passes through Greenwich, England."
            ],
            "correctAnswer": 1
        },
        {
            "id": 54,
            "question": "The most comprehensive information on a given airport is provided by",
            "options": [
                "the Chart Supplements U.S. (formerly Airport Facility Directory).",
                "Notices to Airmen (NOTAMS).",
                "Terminal Area Chart (TAC)."
            ],
            "correctAnswer": 0
        },
        {
            "id": 55,
            "question": "When using a small UA in a commercial operation, who is responsible for briefing the participants about emergency procedures?",
            "options": [
                "The FAA inspector-in-charge.",
                "The lead visual observer.",
                "The remote PIC."
            ],
            "correctAnswer": 2
        },
        {
            "id": 56,
            "question": "To avoid a possible collision with a manned airplane, you estimate that your small UA climbed to an altitude greater than 600 feet AGL. To whom must you report the deviation?",
            "options": [
                "Air Traffic Control.",
                "The National Transportation Safety Board.",
                "Upon request of the Federal Aviation Administration."
            ],
            "correctAnswer": 2
        },
        {
            "id": 57,
            "question": "What precautions should a remote PIC do to prevent possible inflight emergencies when using lithium-based batteries?",
            "options": [
                "Store the batteries in a freezer to allow proper recharging.",
                "Follow the manufacturers recommendations for safe battery handling.",
                "Allow the battery to charge until it reaches a minimum temperature of 100 °."
            ],
            "correctAnswer": 1
        },
        {
            "id": 58,
            "question": "Safety is an important element for a remote pilot to consider prior to operating an unmanned aircraft system. To prevent the final \"link\" in the accident chain, a remote pilot must consider which methodology?",
            "options": [
                "Crew Resource Management.",
                "Safety Management System.",
                "Risk Management."
            ],
            "correctAnswer": 2
        },
        {
            "id": 59,
            "question": "A local TV station has hired a remote pilot to operate their small UA to cover breaking news stories. The remote pilot has had multiple near misses with obstacles on the ground and two small UAS accidents. What would be a solution for the news station to improve their operating safety culture?",
            "options": [
                "The news station should implement a policy of no more than five crashes/incidents within 6 months.",
                "The news station does not need to make any changes; there are times that an accident is unavoidable.",
                "The news station should recognize hazardous attitudes and situations and develop standard operating procedures that emphasize safety."
            ],
            "correctAnswer": 2
        },
        {
            "id": 60,
            "question": "When adapting crew resource management (CRM) concepts to the operation of a small UA, CRM must be integrated into",
            "options": [
                "the flight portion only.",
                "all phases of the operation.",
                "the communications only."
            ],
            "correctAnswer": 1
        },
        {
            "id": 61,
            "question": "When a remote pilot-in-command and a visual observer define their roles and responsibilities prior to and during the operation of a small UA is a good use of",
            "options": [
                "Crew Resource Management.",
                "Authoritarian Resource Management.",
                "Single Pilot Resource Management."
            ],
            "correctAnswer": 0
        },
        {
            "id": 62,
            "question": "Identify the hazardous attitude or characteristic a remote pilot displays while taking risks in order to impress others?",
            "options": [
                "Impulsivity.",
                "Invulnerability.",
                "Macho."
            ],
            "correctAnswer": 2
        },
        {
            "id": 63,
            "question": "You have been hired as a remote pilot by a local TV news station to film breaking news with a small UA. You expressed a safety concern and the station manager has instructed you to \"fly first, ask questions later.\" What type of hazardous attitude does this attitude represent?",
            "options": [
                "Machismo.",
                "Invulnerability.",
                "Impulsivity."
            ],
            "correctAnswer": 2
        },
        {
            "id": 64,
            "question": "Which is true regarding the presence of alcohol within the human body?",
            "options": [
                "small amount of alcohol increases vision acuity.",
                "Consuming an equal amount of water will increase the destruction of alcohol and alleviate a hangover.",
                "Judgment and decision-making abilities can be adversely affected by even small amounts of alcohol."
            ],
            "correctAnswer": 2
        },
        {
            "id": 65,
            "question": "You are a remote pilot for a co-op energy service provider. You are to use your UA to inspect power lines in a remote area 15 hours away from your home office. After the drive, fatigue impacts your abilities to complete your assignment on time. Fatigue can be recognized",
            "options": [
                "easily by an experienced pilot.",
                "as being in an impaired state.",
                "by an ability to overcome sleep deprivation."
            ],
            "correctAnswer": 1
        },
        {
            "id": 66,
            "question": "Which technique should a remote pilot use to scan for traffic? A remote pilot should",
            "options": [
                "systematically focus on different segments of the sky for short intervals.",
                "concentrate on relative movement detected in the peripheral vision area.",
                "continuously scan the sky from right to left."
            ],
            "correctAnswer": 0
        },
        {
            "id": 67,
            "question": "When preparing for a night flight, what should an sUAS pilot be aware of after assembling and conducting a preflight of an aircraft while using a bright flashlight or work light?",
            "options": [
                "Once adapted to darkness, a persons eyes are relatively immune to bright lights.",
                "It takes approximately 30 minutes for a persons eyes to fully adapt to darkness.",
                "The person should use a flash light equipped with LED lights to facilitate their night vision."
            ],
            "correctAnswer": 1
        },
        {
            "id": 68,
            "question": "Under what condition should the operator of a small UA establish scheduled maintenance protocol?",
            "options": [
                "When the manufacturer does not provide a maintenance schedule.",
                "UAS does not need a required maintenance schedule.",
                "When the FAA requires you to, following an accident."
            ],
            "correctAnswer": 0
        },
        {
            "id": 69,
            "question": "What actions should the operator of an sUAS do if the manufacturer does not provide information about scheduled maintenance?",
            "options": [
                "The operator should contact the FAA for a minimum equipment list.",
                "The operator should establish a scheduled maintenance protocol.",
                "The operator should contact the NTSB for component failure rates for their specific sUAS."
            ],
            "correctAnswer": 1
        },
        {
            "id": 70,
            "question": "According to 14 CFR part 107, the responsibility to inspect the small UAS to ensure it is in a safe operating condition rests with the",
            "options": [
                "remote pilot-in-command.",
                "visual observer.",
                "owner of the small UAS."
            ],
            "correctAnswer": 0
        }
    ]
}
$$::jsonb,
updated_at = NOW()
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-000000000001';

-- Verify all 70 questions were added
SELECT 
    test_name,
    jsonb_array_length(questions->'questions') as total_questions,
    questions->'questions'->0->>'question' as first_question,
    questions->'questions'->69->>'question' as last_question
FROM course_tests
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-000000000001';

-- Expected output:
-- total_questions: 70
-- first_question: "A small UA causes an accident..."
-- last_question: "According to 14 CFR part 107, the responsibility..."

