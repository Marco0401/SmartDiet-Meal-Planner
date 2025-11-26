# Analytics Export Feature

## Overview
The Analytics page now includes comprehensive export functionality that allows administrators to download various reports as CSV files.

## Export Options

### 1. Full Analytics Report
**Includes:**
- Key metrics (users, recipes, meal plans, nutrition entries)
- Growth percentages for each metric
- Top 10 most popular recipes with usage counts
- Allergen statistics across all users
- User registration trends (daily breakdown)

**Filename:** `smartdiet_full_report_YYYYMMDD_HHMMSS.csv`

### 2. Top Recipes Report
**Includes:**
- Ranked list of most popular recipes
- Recipe type classification (Filipino, Italian, Asian, API, Admin, General)
- Usage count for each recipe
- Percentage of total usage
- Summary statistics

**Filename:** `smartdiet_top_recipes_YYYYMMDD_HHMMSS.csv`

### 3. User Statistics Report
**Includes:**
- Total users count
- New users in selected time range
- Growth rate percentage
- Daily registration trends
- Average registrations per day

**Filename:** `smartdiet_user_stats_YYYYMMDD_HHMMSS.csv`

### 4. Allergen Report
**Includes:**
- List of all allergens declared by users
- User count for each allergen
- Percentage distribution
- Total allergen declarations
- Unique allergen count

**Filename:** `smartdiet_allergen_report_YYYYMMDD_HHMMSS.csv`

## How to Use

### CSV Export
1. Navigate to the Analytics page in the admin panel
2. Click the download icon (📥) in the top-right corner
3. Select the type of report you want to export
4. Click the **CSV icon** (📊) next to the report
5. The CSV file will automatically download to your browser's download folder

### Print Preview
1. Navigate to the Analytics page in the admin panel
2. Click the download icon (📥) in the top-right corner
3. Select the type of report you want to export
4. Click the **Print icon** (🖨️) next to the report
5. Review the beautifully formatted print preview
6. Click "Print" to print or save as PDF

## Features

### Export Options
- **CSV Export**: Download data in spreadsheet format
- **Print Preview**: View beautifully formatted reports before printing

### Report Features
- **Time Range Filtering**: Reports respect the selected time range (24 hours, 7 days, 30 days, 90 days)
- **Real-time Data**: All reports pull live data from Firestore
- **Loading Indicators**: Shows progress while generating reports
- **Success/Error Feedback**: Clear notifications when export completes or fails
- **Automatic Timestamps**: Each report includes generation date/time
- **Web-Optimized**: Uses browser's native download and print functionality

### Print Preview Design
- **Professional Layout**: Clean, organized document structure
- **Color-Coded Sections**: Easy-to-read visual hierarchy
- **Branded Header**: SmartDiet logo and report title
- **Metadata Display**: Generation date, time range, and page numbers
- **Formatted Tables**: Alternating row colors for readability
- **Metric Cards**: Visual cards with icons and growth indicators
- **Summary Boxes**: Highlighted key statistics
- **Footer**: Confidential marking and page numbering

## Technical Details

### Dependencies
- `csv: ^6.0.0` - CSV file generation
- `dart:html` - Browser download functionality
- `dart:convert` - UTF-8 encoding

### Data Sources
All reports pull data from:
- `users` collection
- `users/{userId}/favorites` subcollection
- `users/{userId}/meal_plans` subcollection
- `announcements` collection

### CSV Format
- UTF-8 encoded
- Comma-separated values
- Headers included
- Compatible with Excel, Google Sheets, and other spreadsheet applications

## Use Cases

1. **Business Intelligence**: Track app usage and user engagement
2. **Health Insights**: Understand common allergens and dietary needs
3. **Recipe Optimization**: Identify most popular recipes to feature
4. **Growth Analysis**: Monitor user acquisition trends
5. **Compliance**: Generate reports for stakeholders or audits

## Print Preview Screenshots

The print preview feature provides:
- **Full-width layout** optimized for A4/Letter paper
- **Professional styling** with SmartDiet branding
- **Color-coded metrics** for quick visual scanning
- **Clean tables** with headers and alternating row colors
- **Responsive design** that looks great on screen and paper

## Browser Print Options

When you click "Print" from the preview:
- **Save as PDF**: Most browsers allow saving to PDF
- **Physical Print**: Send directly to a printer
- **Page Setup**: Adjust margins, orientation, and scale
- **Print Selection**: Choose specific pages if needed

## Future Enhancements

Potential additions:
- Direct PDF download (without print dialog)
- Scheduled automatic reports
- Email delivery of reports
- Custom date range selection
- Chart/graph exports in print view
- Multi-format support (JSON, XML)
- Custom branding/logo upload
