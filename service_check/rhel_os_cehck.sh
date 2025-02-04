#!/bin/bash

# 날짜로 결과를 저장할 디렉토리 설정
today=$(date '+%Y-%m-%d')
OUTPUT_DIR="check_report/os_check_$today"
mkdir -p "$OUTPUT_DIR"
os_version=$(cat /etc/os-release)
kernel_version=$(uname -a)

# HTML 파일 경로 설정
HTML_FILE="$OUTPUT_DIR/os_check_report.html"

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
        pre { background-color: #f4f4f4; padding: 10px; border: 1px solid #ddd; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>OS Check Report - $today</h1>
EOF

# 함수: 섹션 추가 (명령 실행 결과)
print_section_html_command() {
    echo "<h2>$2</h2>" >> $HTML_FILE
    echo "<pre>" >> $HTML_FILE
    $1 >> $HTML_FILE 2>&1
    echo "</pre>" >> $HTML_FILE
}

# 함수: 섹션 추가 (이미 실행된 결과)
print_section_html_value() {
    echo "<h2>$2</h2>" >> $HTML_FILE
    echo "<pre>" >> $HTML_FILE
    echo "$1" >> $HTML_FILE
    echo "</pre>" >> $HTML_FILE
}

# OS 정보 수집
print_section_html_value "${os_version}" "1. OS 버전 및 커널 정보"
print_section_html_value "${kernel_version}" "2. 커널 정보"

# Uptime 확인
print_section_html_command "uptime" "3. Uptime (기동시간 및 Load Average)"

# CPU 정보 확인
print_section_html_command "lscpu" "4. CPU 정보"

# 메모리 사용량 확인
print_section_html_command "free -mh" "5. 메모리 사용량"

# /etc/resolv.conf 확인
print_section_html_command "cat /etc/resolv.conf" "6. /etc/resolv.conf 확인"

# NIC 속도 확인
echo "<h2>7. NIC 속도 체크</h2>" >> $HTML_FILE
for nic in $(ls /sys/class/net | grep -v lo); do
    echo "<h3>NIC: $nic</h3>" >> $HTML_FILE
    nic_info=$(ethtool $nic 2>&1)
    echo "<pre>$nic_info</pre>" >> $HTML_FILE
done

# Firewall 설정 확인
firewall_info=$(firewall-cmd --list-all 2>&1 || echo "firewall-cmd 실행 실패")
iptables_info=$(iptables -L 2>&1 || echo "iptables 실행 실패")
print_section_html_value "${firewall_info}" "8. Firewall 설정"
print_section_html_value "${iptables_info}" ""

# HTML 종료 부분 작성
cat <<EOF >> "$HTML_FILE"
</body>
</html>
EOF

echo "HTML report generated at: $HTML_FILE"
