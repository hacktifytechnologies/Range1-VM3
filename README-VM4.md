# eProcure — Simulation Platform
## Tomcat Deployment Guide

> **Simulated training environment — all data is fictional.**

---

## Application Structure

```
eprocure.war / eprocure/
├── login.html          ← Entry point (login page)
├── index.html          ← Main app (dashboard + all modules)
├── error.html          ← 404/500 error page
├── css/
│   └── style.css       ← Complete stylesheet
├── js/
│   └── app.js          ← All JavaScript
└── WEB-INF/
    └── web.xml         ← Tomcat deployment descriptor
```

---

## Deploy to Tomcat

### Step 1 — Package as WAR

```bash
# Navigate to the eprocure folder
cd /path/to/eprocure/

# Create WAR using zip (works everywhere)
zip -r eprocure.war .

# OR using jar (if JDK installed)
jar -cvf eprocure.war .
```

### Step 2 — Copy to Tomcat

```bash
cp eprocure.war $CATALINA_HOME/webapps/
```

On Windows:
```cmd
copy eprocure.war %CATALINA_HOME%\webapps\
```

### Step 3 — Start Tomcat

```bash
# Linux/macOS
$CATALINA_HOME/bin/startup.sh

# Windows
%CATALINA_HOME%\bin\startup.bat
```

### Step 4 — Open in Browser

```
http://localhost:8080/eprocure/
```

Tomcat auto-redirects to `login.html`.

---

## Login Credentials

| Field    | Value           |
|----------|-----------------|
| Email    | demo@eproc.in   |
| Password | Admin@123       |

---

## Tomcat Version Notes

| Tomcat | Java  | web.xml Schema |
|--------|-------|----------------|
| 10.x / 11.x | Java 11+ | Jakarta EE 6.0 (current) |
| 9.x    | Java 8+ | Java EE 4.0 (update needed) |

### For Tomcat 9.x — update web.xml opening tag:

```xml
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
                             http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
```

---

## Modules Included

| Module               | Description |
|----------------------|-------------|
| 🔐 Login             | Simulated authentication with demo credentials |
| 📊 Dashboard         | KPI stats, procurement pipeline, activity feed |
| 📋 Tender Management | CRUD table, workflow steps, filters, CSV export, corrigendum |
| 📨 Bid Evaluation    | L1/L2/L3 scoring matrix, committee sign-off |
| 🏢 Vendor Registry   | KYC workflow, performance scores, blacklist |
| 📄 Contracts         | Active contracts, milestone tracking |
| 💳 Payments          | Invoice queue, approval workflow, overdue alerts |
| 📈 Reports           | Spend analysis, compliance dashboard, print/export |
| ⚙️ Settings          | Profile, security, DSC, preferences |

---

## Notes

- Pure HTML + CSS + JS — **no backend required**
- No real-world entities, government bodies, or actual domains referenced
- Fonts loaded from Google Fonts CDN (requires internet on first load)
- All data is hardcoded for demonstration purposes
