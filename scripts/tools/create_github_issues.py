#!/usr/bin/env python3
"""
Sync tasks from tasks.md to GitHub Issues for AslanMurzalin/Ant-Colony
"""

import json
import re
import subprocess
import time
import urllib.request
import urllib.error
from pathlib import Path

REPO = "AslanMurzalin/Ant-Colony"
API_BASE = f"https://api.github.com/repos/{REPO}"

def get_token():
    p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = p.communicate('protocol=https\nhost=github.com\n\n')
    creds = dict(line.split('=', 1) for line in out.strip().splitlines() if '=' in line)
    token = creds.get('password')
    if not token:
        raise RuntimeError("Could not find GitHub token from git credentials.")
    return token

def api_request(url, data=None, token=None, method=None):
    headers = {
        "User-Agent": "AntColony-Sync",
        "Accept": "application/vnd.github.v3+json",
    }
    if token:
        headers["Authorization"] = f"token {token}"
    
    body = None
    if data is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(data).encode("utf-8")
        
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"HTTP Error {e.code} for {url}: {error_body}")
        raise

def setup_labels(token):
    labels_to_create = [
        {"name": "Dev A: Ruslan", "color": "1d76db", "description": "Backend logic and simulation systems"},
        {"name": "Dev B: Aslan", "color": "0e8a16", "description": "Tilemap, visuals, UI and effects"},
        {"name": "Phase 1: Foundations", "color": "c5def5", "description": "Phase 1: Foundations & Core Architecture"},
        {"name": "Phase 2: Ants & Queen", "color": "bfdadc", "description": "Phase 2: Worker Ants & Queen"},
        {"name": "Phase 3: Economy", "color": "d4c5f9", "description": "Phase 3: Resource Economy & Growth"},
        {"name": "Phase 4: Threats", "color": "e99695", "description": "Phase 4: Threats & Combat"},
        {"name": "Phase 5: Polish & Loop", "color": "f9d0c4", "description": "Phase 5: UI, 10-Day Loop & Final Polish"},
    ]
    
    existing = {l["name"]: l for l in api_request(f"{API_BASE}/labels", token=token)}
    for label in labels_to_create:
        if label["name"] not in existing:
            try:
                api_request(f"{API_BASE}/labels", data=label, token=token)
                print(f"Created label: {label['name']}")
            except Exception as e:
                print(f"Could not create label {label['name']}: {e}")

def parse_tasks_md(tasks_file: Path):
    content = tasks_file.read_text(encoding="utf-8")
    
    phase_pattern = re.compile(r"## (Phase \d+: [^\n]+)")
    task_pattern = re.compile(
        r"- \[ \] \*\*Task (\d+\.\d+[AB]) — ([^\n]+)\*\*\n"
        r"\s+- \*\*Goal:\*\* ([^\n]+)\n"
        r"\s+- \*\*Deliverable:\*\* ([^\n]+)\n"
        r"\s+- \*\*Acceptance Criteria:\*\* ([^\n]+)"
    )
    
    sections = re.split(r"(## Phase \d+: [^\n]+)", content)
    tasks = []
    
    current_phase = "Phase 1: Foundations"
    for part in sections:
        if part.startswith("## Phase"):
            current_phase = part.replace("## ", "").strip()
            continue
        
        for m in task_pattern.finditer(part):
            task_id = m.group(1)
            title = m.group(2)
            goal = m.group(3)
            deliverable = m.group(4)
            acceptance = m.group(5)
            
            phase_short = current_phase.split(":")[0].strip()
            if "Dev A" in title:
                dev = "Dev A: Ruslan"
            elif "Dev B" in title:
                dev = "Dev B: Aslan"
            else:
                dev = "Dev A: Ruslan" if "A" in task_id else "Dev B: Aslan"
                
            tasks.append({
                "id": task_id,
                "title": f"Task {task_id}: {title}",
                "phase": current_phase,
                "dev": dev,
                "goal": goal,
                "deliverable": deliverable,
                "acceptance": acceptance,
            })
            
    return tasks

def main():
    token = get_token()
    print(f"Authenticated with GitHub token for repo: {REPO}")
    setup_labels(token)
    
    tasks_file = Path(__file__).resolve().parent.parent.parent / "tasks.md"
    tasks = parse_tasks_md(tasks_file)
    print(f"Parsed {len(tasks)} tasks from tasks.md")
    
    created_count = 0
    for task in tasks:
        # Determine labels
        phase_label = None
        if "Phase 1" in task["phase"]:
            phase_label = "Phase 1: Foundations"
        elif "Phase 2" in task["phase"]:
            phase_label = "Phase 2: Ants & Queen"
        elif "Phase 3" in task["phase"]:
            phase_label = "Phase 3: Economy"
        elif "Phase 4" in task["phase"]:
            phase_label = "Phase 4: Threats"
        elif "Phase 5" in task["phase"]:
            phase_label = "Phase 5: Polish & Loop"
            
        labels = [task["dev"]]
        if phase_label:
            labels.append(phase_label)
            
        body = f"""### 🎯 Goal
{task['goal']}

### 📦 Deliverable
{task['deliverable']}

### ✅ Acceptance Criteria
{task['acceptance']}

---
### 🚨 Invariant Check & Verification
- Follow [GD.md](https://github.com/{REPO}/blob/main/GD.md) specifications.
- Update [Contracts.md](https://github.com/{REPO}/blob/main/Contracts.md) immediately for any newly declared or modified functions/signals.
- Adhere to [Agents.md](https://github.com/{REPO}/blob/main/Agents.md) static typing rules.
- Run automated contract checker before closing:
  ```powershell
  python scripts/tools/check_contracts.py
  ```
"""
        payload = {
            "title": task["title"],
            "body": body,
            "labels": labels
        }
        
        try:
            res = api_request(f"{API_BASE}/issues", data=payload, token=token)
            issue_num = res.get("number")
            issue_url = res.get("html_url")
            print(f"[{created_count+1}/{len(tasks)}] Created Issue #{issue_num}: {task['title']} -> {issue_url}")
            created_count += 1
            time.sleep(0.7) # Respect GitHub secondary rate limits
        except Exception as e:
            print(f"Error creating issue for {task['title']}: {e}")
            break
            
    print(f"\n🎉 Successfully created {created_count} issues in {REPO}!")

if __name__ == "__main__":
    main()
