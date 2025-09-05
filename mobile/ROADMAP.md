# OpenNoiseNet Mobile App Roadmap

## 🎯 Vision
Transform the mobile app from a simple SPL display into a complete **noise event detection and recording system** that contributes to the global OpenNoiseNet platform for environmental noise monitoring.

## 📊 Current Status

### ✅ Completed Features
- [x] Real-time audio monitoring with SPL visualization
- [x] Audio waveform display with peak hold
- [x] SQLite database for unified data storage
- [x] Audio recording service (15-minute WAV files)
- [x] Event detection service framework
- [x] Location services integration
- [x] Dark/light theme support
- [x] Settings management (thresholds, calibration)
- [x] Preferences migration system

### ⚠️ Current Limitations
- **Critical Gap**: Audio monitoring and event detection are not connected
- No automatic event detection happening
- No automatic recordings triggered by loud events
- No noise events being stored or displayed
- Backend integration incomplete

---

## 🚀 Phase 1: Core Event Detection System
**Goal**: Connect audio monitoring to event detection for automated noise event capture

### 1.1 Connect Audio Pipeline
- [ ] Feed SPL samples from `AudioCaptureService` to `EventDetectionService`
- [ ] Start/stop event detection with monitoring lifecycle
- [ ] Store noise measurements in SQLite database
- [ ] Add real-time event status to monitoring UI

### 1.2 Automatic Event Handling  
- [ ] Implement threshold-based event detection (configurable dB levels)
- [ ] Trigger audio recording when events are detected
- [ ] Calculate Leq15 (15-minute equivalent levels) for events
- [ ] Add location tagging to detected events
- [ ] Show event notifications to user

### 1.3 Event Storage & Retrieval
- [ ] Enhance noise event database schema
- [ ] Store complete events with audio file references  
- [ ] Add event metadata (duration, peak levels, exceedance percentages)
- [ ] Implement event cleanup (7-day retention policy)

**Deliverable**: Working noise event detection that automatically records audio during loud periods

---

## 🔧 Phase 2: User Interface & Management
**Goal**: Provide comprehensive event management and monitoring dashboard

### 2.1 Events Dashboard
- [ ] Create noise events history page
- [ ] Display detected events with timeline
- [ ] Show event details (duration, levels, location)
- [ ] Add event playback functionality
- [ ] Filter events by date, level, duration

### 2.2 Enhanced Monitoring UI
- [ ] Add real-time event detection indicators
- [ ] Display current threshold status
- [ ] Show event counter and statistics
- [ ] Add "Events Today" summary card
- [ ] Integrate event timeline in monitoring view

### 2.3 Configuration & Calibration
- [ ] Advanced threshold configuration (day/night profiles)
- [ ] Time window settings (5min, 15min, custom)
- [ ] Audio recording preferences (quality, duration)
- [ ] Device calibration wizard with reference tones
- [ ] Export/import settings functionality

**Deliverable**: Complete user interface for viewing and managing noise events

---

## 🌐 Phase 3: Backend Integration & Submission
**Goal**: Connect to OpenNoiseNet platform for data sharing and analysis

### 3.1 Event Submission System
- [ ] Implement event submission to backend API
- [ ] Add event review interface (approve/reject before submission)
- [ ] Support manual event submission
- [ ] Handle offline queuing and retry logic
- [ ] Add submission status tracking

### 3.2 Data Synchronization
- [ ] Automatic event submission (configurable)
- [ ] Sync device statistics and calibration data
- [ ] Download community noise maps
- [ ] Push notifications for nearby events
- [ ] Handle API authentication and device registration

### 3.3 Privacy & Compliance
- [ ] Implement GDPR-compliant data handling
- [ ] Optional audio snippet encryption
- [ ] User consent management
- [ ] Data retention policy enforcement
- [ ] Anonymous vs. identified submission modes

**Deliverable**: Full backend integration with automated event submission to OpenNoiseNet platform

---

## 🧠 Phase 4: Advanced Analytics & AI
**Goal**: Add intelligent analysis and pattern recognition capabilities

### 4.1 Audio Analysis & Classification
- [ ] Implement basic audio classification (traffic, construction, nature)
- [ ] Add spectral analysis for event fingerprinting
- [ ] Detect recurring noise patterns
- [ ] Implement A-weighting and frequency analysis
- [ ] Add psychoacoustic metrics (loudness, sharpness)

### 4.2 Smart Detection
- [ ] Machine learning-based event classification
- [ ] Adaptive threshold adjustment based on ambient levels
- [ ] False positive reduction algorithms
- [ ] Periodic noise pattern detection
- [ ] Integration with external audio analysis APIs

### 4.3 Advanced Statistics
- [ ] Daily/weekly/monthly noise statistics
- [ ] Noise dose calculations (exposure metrics)
- [ ] Correlation with weather data
- [ ] Community noise level comparisons
- [ ] Generate automated noise reports

**Deliverable**: Intelligent noise analysis with automatic event classification

---

## 📱 Phase 5: Platform & User Experience
**Goal**: Polish the app for public release and community use

### 5.1 User Onboarding
- [ ] Welcome tutorial and app overview
- [ ] Microphone calibration walkthrough
- [ ] Location permission education
- [ ] Community participation explanation
- [ ] Quick setup wizard

### 5.2 Community Features  
- [ ] Local noise level comparisons
- [ ] Community event notifications
- [ ] Nearby sensor network display
- [ ] Collaborative noise mapping
- [ ] User feedback and reporting system

### 5.3 Performance & Reliability
- [ ] Battery optimization for continuous monitoring
- [ ] Background monitoring capabilities
- [ ] Crash reporting and analytics
- [ ] App performance monitoring
- [ ] Memory usage optimization

### 5.4 Platform Integration
- [ ] Apple Watch companion app
- [ ] Today widget for quick noise levels
- [ ] Shortcuts app integration
- [ ] CarPlay support for in-vehicle monitoring
- [ ] Export to Apple Health/Google Fit

**Deliverable**: Production-ready app for public release

---

## 🎯 Success Metrics

### Technical KPIs
- **Event Detection Accuracy**: >90% precision for noise events >65dB
- **Battery Life**: <10% drain per hour during continuous monitoring  
- **False Positive Rate**: <5% for event detection
- **Data Submission Success**: >95% successful uploads when online

### User Experience KPIs
- **Setup Completion Rate**: >80% users complete initial calibration
- **Daily Active Users**: Target 1000+ contributors
- **Event Submission Rate**: >60% of detected events submitted
- **User Retention**: >40% monthly retention rate

### Impact KPIs  
- **Community Coverage**: 100+ active sensors per major city
- **Data Quality**: Correlation >0.8 with professional monitors
- **Scientific Use**: Integration with 5+ research projects
- **Policy Impact**: Used in 10+ noise complaint cases

---

## 🛠️ Technical Architecture

### Core Services
- `AudioCaptureService`: Real-time SPL monitoring
- `EventDetectionService`: Threshold-based event detection  
- `AudioRecordingService`: Automated recording during events
- `LocationService`: GPS tagging for events
- `EventSubmissionService`: Backend API integration

### Data Flow
```
Microphone → AudioCapture → EventDetection → Recording + Storage → Submission → OpenNoiseNet
                ↓                ↓              ↓
           UI Display      Event Alerts    Local Database
```

### Database Schema
- `noise_measurements`: Raw SPL samples
- `noise_events`: Detected events with metadata
- `audio_recordings`: Recorded audio files
- `daily_statistics`: Aggregated daily metrics
- `preferences`: User settings and calibration

---

## 🚦 Next Immediate Actions

1. **[HIGH PRIORITY]** Connect `AudioCaptureService` to `EventDetectionService` 
2. **[HIGH PRIORITY]** Implement automatic event detection in `MonitoringBloc`
3. **[MEDIUM PRIORITY]** Add noise events storage to database
4. **[MEDIUM PRIORITY]** Create basic events dashboard UI
5. **[LOW PRIORITY]** Implement event submission to backend

---

## 📅 Timeline Estimate

- **Phase 1**: 2-3 weeks (Core event detection system)
- **Phase 2**: 3-4 weeks (UI and management features) 
- **Phase 3**: 4-5 weeks (Backend integration)
- **Phase 4**: 6-8 weeks (Advanced analytics)
- **Phase 5**: 4-6 weeks (Platform polish)

**Total Estimated Timeline**: 19-26 weeks (~5-6 months)

---

## 🎉 Definition of Done

The OpenNoiseNet mobile app will be **complete** when:

1. ✅ **Automatically detects** noise events based on configurable thresholds
2. ✅ **Records audio samples** during detected events  
3. ✅ **Stores events locally** with location and metadata
4. ✅ **Submits data** to the OpenNoiseNet backend platform
5. ✅ **Provides insights** through statistics and event history
6. ✅ **Integrates seamlessly** with the broader OpenNoiseNet ecosystem
7. ✅ **Maintains user privacy** while contributing to community science

**The ultimate goal**: Transform citizen smartphones into a global network of environmental noise sensors that contribute valuable data for research, policy, and community advocacy.