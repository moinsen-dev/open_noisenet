# OpenNoiseNet Landing Page

## Overview
The landing page now features a powerful dual-story approach that transforms the user experience from emotional connection to technical understanding to actionable engagement.

## Page Structure

### 🎭 Story Page (/) - The Emotional Hook
**Route**: `/`
**Purpose**: Show the human impact of noise pollution
**Components**:
- Hero section: "When Noise Never Sleeps"
- 7 emotional story cards (onn-1 to onn-7 images)
- Transition section: "But What If We Could Change This?"
- Primary CTA: "See How We Fix This" → `/technology`

**Narrative Arc**:
1. The Quiet We Lost
2. Sleep Interrupted  
3. The Health Crisis
4. The Breaking Point
5. Individual Helplessness
6. Community Frustration
7. The Hope for Change

### 🔧 Technology Page (/technology) - The Solution
**Route**: `/technology`
**Purpose**: Show how OpenNoiseNet technology creates change
**Components**:
- Hero section: "The Technology Behind Change"
- 7 technology story cards (tech-4 to tech-10 specifications)
- GitHub integration and open source links
- Primary CTA: "Get Started Today" → `/devices`

**Technology Narrative Arc**:
1. **The Silent Guardian** - Phone transformation
2. **The Privacy Shield** - Edge computing privacy
3. **The Pattern Hunter** - Local AI classification
4. **The Time Detective** - Temporal pattern analysis
5. **The Network Effect** - Distributed sensing
6. **The Evidence Builder** - Analytics and reporting
7. **The Change Catalyst** - Measurable community impact

### 📱 Navigation Flow
```
Story Page → Technology Page → Get Started → Live Map
    ↓           ↓                ↓            ↓
[Emotional]  [Technical]     [Action]    [Results]
```

## Design System

### Color Palette
- **Primary Background**: `#1a2332` (Dark Blue)
- **Primary Accent**: `#ff6b35` (Orange)
- **Text Colors**: White, `theme.palette.grey[300]`
- **Gradients**: Linear gradients from dark blue to grey

### Typography
- **Headers**: Bold, gradient text effects
- **Body**: Clean, readable with proper line-height
- **Accent Text**: Orange highlights for key messages

### Layout
- **Full-screen pages**: No sidebar, minimal header
- **Responsive**: Mobile-first design with staggered animations
- **Cards**: Dark backgrounds with hover effects
- **CTAs**: Prominent orange buttons with hover animations

## Technical Implementation

### Components
- `HomePage.tsx` - Emotional story sequence
- `TechnologyPage.tsx` - Technical solution sequence  
- `Layout.tsx` - Dual layout (landing vs dashboard)
- `App.tsx` - Smart routing for full-screen pages

### Features
- **Staggered Animations**: Cards appear with delays for dramatic effect
- **Smooth Transitions**: Page-to-page navigation with context preservation
- **Responsive Design**: Works on all device sizes
- **Image Optimization**: Proper asset loading and fallbacks

### Assets Required
**Story Images** (existing):
- `/public/images/story/onn-1.png` through `onn-7.png`

**Technology Images** (to be created from specifications):
- `/public/images/technology/tech-4.png` through `tech-10.png`

## Content Strategy

### Dual Narrative Approach
The landing page uses a **complementary narrative structure**:

| **Emotional Story** | **Technology Story** |
|-------------------|---------------------|
| Problem: Noise disrupts sleep | Solution: Device transformation |
| Impact: Personal suffering | Method: Privacy-first architecture |
| Frustration: Helplessness | Intelligence: Edge AI classification |
| Pattern: Recurring disruption | Analysis: Temporal pattern detection |
| Community: Shared experience | Network: Distributed sensing |
| Need: Evidence for change | Evidence: Analytics and reporting |
| Hope: Quieter future | Impact: Measurable improvement |

### Conversion Funnel
1. **Awareness** (Story Page): Emotional connection to the problem
2. **Interest** (Technology Page): Technical credibility and innovation
3. **Desire** (CTAs): Clear path to participation
4. **Action** (Get Started): Device setup and community joining

## Development Status

### ✅ Completed
- [x] Story page with emotional narrative
- [x] Technology page with solution narrative
- [x] Responsive design for all devices
- [x] Navigation between pages
- [x] Interactive animations and hover effects
- [x] Asset integration and optimization

### 🎨 Image Creation Needed
The technology page currently uses placeholders. Create final images using the specifications in `/images/technology/image-specifications.md`:

1. tech-4.png: The Silent Guardian
2. tech-5.png: The Privacy Shield  
3. tech-6.png: The Pattern Hunter
4. tech-7.png: The Time Detective
5. tech-8.png: The Network Effect
6. tech-9.png: The Evidence Builder
7. tech-10.png: The Change Catalyst

### 📊 Future Enhancements
- Analytics integration for conversion tracking
- A/B testing framework for story variations
- Interactive demos of technology features
- User-generated content integration
- Multilingual support

## Local Development

```bash
cd frontend
npm run dev
```

Visit `http://localhost:3000` to see the story page and `http://localhost:3000/technology` for the technology page.

## Deployment Notes

The landing page is designed to work seamlessly with the existing dashboard functionality while providing a completely different user experience for public visitors versus authenticated users.