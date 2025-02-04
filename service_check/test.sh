#!/bin/bash

# 기존 파일 삭제
rm -rf "$OUTPUT_DIR"
#if [[ ls -l ]]; then
#  rm -rf "$OUTPUT_DIR"
#fi

# 날짜로 결과를 저장할 디렉토리 설정
today=$(date '+%Y-%m-%d')
OUTPUT_DIR="check_report/os_check_$today"
mkdir -p "$OUTPUT_DIR"

# OS 및 시스템 정보 가져오기
host_info=$(hostname 2>/dev/null || echo "hostname 확인 실패")
os_version=$(cat /etc/os-release 2>/dev/null || echo "OS 버전 확인 실패")
kernel_version=$(uname -r 2>/dev/null || echo "커널 버전 확인 실패")
uptime_info=$(uptime 2>/dev/null || echo "시간 확인 실패")
cpu_info=$(lscpu 2>/dev/null || echo "CPU 확인 실패")
mem_info=$(free -mh 2>/dev/null || echo "메모리 확인 실패")
resolv_info=$(cat /etc/resolv.conf 2>/dev/null || echo "resolv 확인 실패")
firewall_info=$(sudo firewall-cmd --list-all 2>/dev/null || echo "firewall-cmd 실행 실패")
iptables_info=$(sudo iptables -L 2>/dev/null || echo "iptables 실행 실패")
ufw_info=$(sudo ufw show raw 2>/dev/null || echo "ufw 실행 실패")

# 점검 상태
os_status="⭕️"
os_issues=""
kernel_status="⭕️"
kernel_issues=""
nic_status="⭕️"
nic_issues=""

# OS 및 커널 특이사항 확인
if [[ ! $os_version =~ "Ubuntu" ]]; then
    os_status="❌"
    os_issues+="<li>OS 버전이 예상과 다릅니다.</li>"
fi

if [[ $kernel_version != "5.15.0-72-generic" ]]; then
    kernel_status="❌"
    kernel_issues+="<li>커널 버전이 예상과 다릅니다 (현재: $kernel_version).</li>"
fi

# NIC 상태 확인
for nic in $(ls /sys/class/net | grep -v lo); do
    speed_file="/sys/class/net/$nic/speed"
    link_file="/sys/class/net/$nic/operstate"

    speed=$(cat "$speed_file" 2>/dev/null || echo "unknown")
    link_status=$(cat "$link_file" 2>/dev/null || echo "unknown")

    # 속도가 1000Mbps 이하인 경우
    if [[ "$speed" != "unknown" && "$speed" -lt 1000 ]]; then
        nic_status="❌"
        nic_issues+="<li>NIC: $nic 속도가 $speed Mbps로 낮습니다.</li>"
    fi

    # NIC 상태가 "up"이 아닌 경우
    if [[ "$link_status" != "up" ]]; then
        nic_status="❌"
        nic_issues+="<li>NIC: $nic 상태가 비정상($link_status)입니다.</li>"
    fi
done

# HTML 파일 경로 설정
HTML_FILE="$OUTPUT_DIR/os_check_report_$host_info.html"
touch $HTML_FILE

# HTML 시작 부분 작성
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset="UTF-8">
    <title>OS Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1, h2 { color: #333; }
        .status-pass { color: green; }
        .status-fail { color: red; }
        pre { background-color: #f4f4f4; padding: 10px; border: 1px solid #ddd; white-space: pre-wrap; }
        .toggle-section { margin-bottom: 20px; }
        .hidden { display: none; }
    </style>
    <script>
        function toggleSection(sectionId) {
            var section = document.getElementById(sectionId);
            if (section.classList.contains('hidden')) {
                section.classList.remove('hidden');
            } else {
                section.classList.add('hidden');
            }
        }
    </script>
</head>
<body>
    <h1>OS Check Report - $today - $host_info</h1>
    <h2>점검 결과 요약</h2>
    <p class="${os_status,,}">OS 상태: <strong>${os_status}</strong></p>
    <p class="${kernel_status,,}">커널 상태: <strong>${kernel_status}</strong></p>
    <p class="${nic_status,,}">NIC 상태: <strong>${nic_status}</strong></p>
EOF

# 특이사항 표시 (특이사항이 있는 경우에만 출력)
if [[ -n "$os_issues" || -n "$kernel_issues" || -n "$nic_issues" ]]; then
    cat <<EOF >> "$HTML_FILE"
    <h3>특이사항:</h3>
    <ul>
        ${os_issues}
        ${kernel_issues}
        ${nic_issues}
    </ul>
EOF
fi

# OS 정보 추가
cat <<EOF >> "$HTML_FILE"
    <div class="toggle-section">
        <button onclick="toggleSection('os-info')">OS 점검 상세 보기</button>
        <div id="os-info" class="hidden">
            <h3>OS 및 커널 정보</h3>
            <pre>$os_version</pre>
            <pre>커널 버전: $kernel_version</pre>
            <pre>$uptime_info</pre>
            <pre>$cpu_info</pre>
            <pre>$mem_info</pre>
            <pre>$resolv_info</pre>
        </div>
    </div>
EOF

# 방화벽 정보 추가
cat <<EOF >> "$HTML_FILE"
    <div class="toggle-section">
        <button onclick="toggleSection('firewall-info')">Firewall 상세 보기</button>
        <div id="firewall-info" class="hidden">
            <h3>Firewall 정보</h3>
            <h4>firewall-cmd 정보</h4>
            <pre>$firewall_info</pre>
            <h4>iptables 정보</h4>
            <pre>$iptables_info</pre>
            <h4>ufw 정보</h4>
            <pre>$ufw_info</pre>
        </div>
    </div>
EOF

# NIC 정보 추가
cat <<EOF >> "$HTML_FILE"
    <div class="toggle-section">
        <button onclick="toggleSection('nic-info')">NIC 점검 상세 보기</button>
        <div id="nic-info" class="hidden">
EOF

for nic in $(ls /sys/class/net | grep -v lo); do
    speed_file="/sys/class/net/$nic/speed"
    link_file="/sys/class/net/$nic/operstate"

    speed=$(cat "$speed_file" 2>/dev/null || echo "unknown")
    link_status=$(cat "$link_file" 2>/dev/null || echo "unknown")

    # NIC 정보 HTML에 추가
    cat <<EOF >> "$HTML_FILE"
            <h3>NIC: $nic</h3>
            <pre>속도: ${speed} Mbps</pre>
            <pre>상태: $link_status</pre>
EOF
done

# NIC 종료
cat <<EOF >> "$HTML_FILE"
        </div> <!-- #nic-info -->
    </div> <!-- .toggle-section -->
EOF

# 추가할 점검 부분을 여기에 써주세요.
cat <<EOF >> "$HTML_FILE"
    <div class="toggle-section">
        <button onclick="toggleSection('add-class')">추가될 점검은?</button>
        <div id="add-class" class="hidden">
        <h4>추가됩니다.</h4>
        </div>
    </div>
EOF

# HTML 끝 부분 작성
cat <<EOF >> "$HTML_FILE"
</body>
</html>
EOF

echo "HTML report generated at: $HTML_FILE"
