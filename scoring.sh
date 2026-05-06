#!/bin/bash
# scoring.sh - main 실행파일 자동채점 (10점 만점)
#
# 사용법:
#   ./scoring.sh              # 전체 채점 (10점 만점, 만점이면 종료코드 0)
#   ./scoring.sh check 0-0    # 2-0 학생정보 항목만 검사 (1점)
#   ./scoring.sh check 0-1    # 2-1 배열주소 항목만 검사 (2점)
#   ./scoring.sh check 0-2    # 2-2 Max/Min/Avg 항목만 검사 (3점)
#   ./scoring.sh check 0-3    # 2-3 학점함수 항목만 검사 (3점)
#   ./scoring.sh check run    # 컴파일/실행 가능 여부만 검사 (1점)
#
# 사전조건: g++ main.cpp -o main 으로 main 실행파일이 만들어져 있어야 함
# 각 항목 검사는 통과 시 종료코드 0, 실패 시 종료코드 1 → GitHub Classroom 호환
#
# GitHub Classroom 테스트 설정 예 (항목별 5개 테스트):
#   1) 컴파일/실행      → ./scoring.sh check run    (1점)
#   2) 학생정보 출력    → ./scoring.sh check 0-0    (1점)
#   3) 배열 주소 연속   → ./scoring.sh check 0-1    (2점)
#   4) Max/Min/Avg      → ./scoring.sh check 0-2    (3점)
#   5) getGrade 함수    → ./scoring.sh check 0-3    (3점)
# 합계 10점, 항목별 통과/실패가 GitHub Classroom에서 부분점수로 합산됨

BIN="./main"
TOTAL=0
MAX=10
LOG=()

# 색상 (TTY일 때만)
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; NC=''
fi

pass() { TOTAL=$((TOTAL + $1)); LOG+=("${GREEN}[PASS +$1]${NC} $2"); }
fail() { LOG+=("${RED}[FAIL  0/$1]${NC} $2"); }
info() { LOG+=("       ${YELLOW}↳${NC} $1"); }

print_result() {
    echo "========================================="
    echo "       자동채점 결과 (./main)"
    echo "========================================="
    printf '%b\n' "${LOG[@]}"
    echo "-----------------------------------------"
    if [ "$TOTAL" -eq "$MAX" ]; then
        echo -e "최종 점수: ${GREEN}${TOTAL}/${MAX}${NC} 🎉"
    elif [ "$TOTAL" -ge 7 ]; then
        echo -e "최종 점수: ${GREEN}${TOTAL}/${MAX}${NC}"
    elif [ "$TOTAL" -ge 4 ]; then
        echo -e "최종 점수: ${YELLOW}${TOTAL}/${MAX}${NC}"
    else
        echo -e "최종 점수: ${RED}${TOTAL}/${MAX}${NC}"
    fi
    echo "========================================="
    echo "POINTS=${TOTAL}/${MAX}"
}

# ─────────────────────────────────────────────────────────
# 사전 검사: ./main 존재 및 실행 가능 여부
# ─────────────────────────────────────────────────────────
if [ ! -f "$BIN" ]; then
    echo -e "${RED}[ERROR]${NC} 실행파일을 찾을 수 없습니다: $BIN"
    echo "  먼저 다음 명령으로 컴파일하세요: g++ main.cpp -o main"
    exit 1
fi
if [ ! -x "$BIN" ]; then
    chmod +x "$BIN" 2>/dev/null
fi

# ─────────────────────────────────────────────────────────
# 헬퍼: 키워드(Max/Min/Avg) 뒤에 오는 숫자만 정확히 추출
#       (학생 이름의 'm'이 'min'으로 오인되는 것 방지)
# ─────────────────────────────────────────────────────────
extract_num() {
    # $1: 키워드 패턴 (대소문자 무시), $2: 출력
    # 키워드 뒤에 숫자가 직접 오거나, 중간에 "is", "값", ":", "=" 같은 연결어가 있어도 매칭
    echo "$2" \
      | grep -iEo "(^|[^a-zA-Z])($1)[^0-9-]*[-+]?[0-9]+(\.[0-9]+)?" \
      | grep -Eo '[-+]?[0-9]+(\.[0-9]+)?$' \
      | head -n1
}

extract_grade() {
    local out=$1 g
    # "Grade:" 키워드 다음의 학점이 있으면 그것을 우선 사용 (첫 번째)
    g=$(echo "$out" | grep -iE 'grade' | grep -oE '[ABCDF]' | head -n1)
    if [ -z "$g" ]; then
        # 키워드가 없으면 출력 후반부에서 단독 학점 라인 찾기
        # (Max/Min/Avg 출력 이후에 나오는 첫 학점이 보통 arr[0]에 해당)
        # 후반부 = 출력의 뒷부분 절반
        local total_lines=$(echo "$out" | wc -l)
        local start=$((total_lines / 2))
        g=$(echo "$out" | tail -n +$start | grep -E '^[[:space:]]*[ABCDF][[:space:]]*$' | head -n1 | tr -d '[:space:]')
    fi
    if [ -z "$g" ]; then
        # 그래도 못 찾으면 마지막 라인의 학점 (예전 방식 fallback)
        g=$(echo "$out" | tail -n1 | grep -oE '[ABCDF]' | tail -n1)
    fi
    echo "$g"
}

# 기댓값 계산: awk로 정확히 처리 (입력값이 무엇이든 대응)
compute_expected() {
    # 입력: 공백 구분된 5개 정수
    # 출력: "max min avg" 한 줄 (avg는 소수점 가능)
    awk '{
        mx=$1; mn=$1; s=$1;
        for (i=2; i<=NF; i++) {
            if ($i > mx) mx = $i;
            if ($i < mn) mn = $i;
            s += $i;
        }
        avg = s / NF;
        printf "%d %d %g\n", mx, mn, avg;
    }' <<< "$1"
}

expected_grade() {
    local s=$1
    if   [ "$s" -ge 90 ] 2>/dev/null; then echo A
    elif [ "$s" -ge 80 ] 2>/dev/null; then echo B
    elif [ "$s" -ge 70 ] 2>/dev/null; then echo C
    elif [ "$s" -ge 60 ] 2>/dev/null; then echo D
    else echo F
    fi
}

# 평균 비교: 진짜 평균과 1 미만 차이면 통과
#   - (double)s/n     → 정확 일치
#   - setprecision(0) → 반올림 정수 (1 미만 차이)
#   - 정수 나눗셈     → 잘림 정수 (1 미만 차이) ※ 출력만으로는 구분 불가
# 학생이 double 연산을 의도했지만 출력 형식 차이로 다른 값이 보일 수 있어
# 이 모든 경우를 정답으로 인정함
near() {
    awk -v got="$1" -v expected="$2" 'BEGIN {
        d = got - expected
        if (d < 0) d = -d
        exit (d < 1.0) ? 0 : 1
    }'
}

# N개 정수를 무작위로 생성 (0~100 범위)
random_input() {
    # $1: 시드용 식별자, $2: 개수
    awk -v seed="$(date +%s%N)$1" -v n="$2" 'BEGIN {
        srand(seed);
        for (i=0; i<n; i++) printf "%d%s", int(rand()*101), (i<n-1?" ":"\n");
    }'
}

# 동일한 정수를 N개 생성 (예: "0 0 0 0 0")
repeat_value() {
    # $1: 값, $2: 개수
    awk -v v="$1" -v n="$2" 'BEGIN {
        for (i=0; i<n; i++) printf "%d%s", v, (i<n-1?" ":"\n");
    }'
}

# 모든 N개 위치를 같은 점수로 채워 입력 생성 (학점 함수 테스트용)
# 학생이 a[0], a[1], a[n-1] 등 어느 인덱스를 쓰든 같은 학점이 나오게 함
grade_input() {
    # $1: 점수, $2: 개수
    awk -v s="$1" -v n="$2" 'BEGIN {
        for (i=0; i<n; i++) printf "%d%s", s, (i<n-1?" ":"\n");
    }'
}

# 오름차순 N개 생성 (10, 20, 30, ...)
ascending_input() {
    # $1: 개수
    awk -v n="$1" 'BEGIN {
        for (i=0; i<n; i++) printf "%d%s", (i+1)*10, (i<n-1?" ":"\n");
    }'
}

# ─────────────────────────────────────────────────────────
# 1) 실행 가능성 검사 + 배열 크기 동적 감지 (1점)
#    충분히 큰 입력을 주고, 출력된 0x주소 개수로 N을 결정
#    (cin >> a[i]는 N개만 소비하고 나머지는 무시되므로 안전)
# ─────────────────────────────────────────────────────────
# N은 1~10 범위로 제한되므로 50개 더미 입력이면 충분
PROBE_INPUT=$(awk 'BEGIN { for (i=0;i<50;i++) printf "%d ", (i%100); print "" }')
SMOKE_OUT=$(echo "$PROBE_INPUT" | timeout 5 "$BIN" 2>/dev/null)
SMOKE_RC=$?

if [ -n "$SMOKE_OUT" ]; then
    pass 1 "실행 성공 (정상 종료)"
elif [ "$SMOKE_RC" -eq 0 ]; then
    pass 1 "실행 성공 (정상 종료)"
else
    fail 1 "실행 실패 (종료코드 $SMOKE_RC)"
    print_result
    exit 0
fi

# 출력된 주소들로부터 배열 크기 N 추정
PROBE_ADDRS=($(echo "$SMOKE_OUT" | grep -Eo '0x[0-9a-fA-F]+'))
N=${#PROBE_ADDRS[@]}

if [ "$N" -ge 1 ]; then
    SIZE_DETECTED=1
else
    # 주소가 없을 때: 다른 방법으로 배열 크기 추정
    SIZE_DETECTED=0

    # 방법 1: 출력 후반부에서 연속된 단독 학점 라인(A/B/C/D/F)의 개수
    # (학생이 모든 원소에 대해 getGrade를 출력한 경우)
    GRADE_LINES=$(echo "$SMOKE_OUT" | grep -cE '^[[:space:]]*[ABCDF][[:space:]]*$')

    # 방법 2: 첫 줄(학생정보) 직후의 연속된 숫자 줄 개수
    # (학생이 &a[i] 대신 a[i]를 출력한 경우)
    NUM_LINES=$(echo "$SMOKE_OUT" | tail -n +2 | awk '
        /^[[:space:]]*-?[0-9]+[[:space:]]*$/ { count++; next }
        { exit }
        END { print count+0 }
    ')

    # 가장 큰 합리적인 값을 채택 (1~10 범위)
    N=5  # fallback
    for candidate in "$GRADE_LINES" "$NUM_LINES"; do
        if [ "$candidate" -ge 1 ] && [ "$candidate" -le 10 ]; then
            N=$candidate
            break
        fi
    done
fi

# N 상한 제한: 어떤 경우에도 1~10 범위로 클램핑
if [ "$N" -gt 10 ]; then
    N=10
elif [ "$N" -lt 1 ]; then
    N=5
fi

# ─────────────────────────────────────────────────────────
# 2) 2-0: 학생 정보 출력 형식 (1점)
#    조건: 첫 줄에 다음 3가지 요소가 모두 존재 (순서/구분자 자유)
#      - 분반: 정확히 2자리 숫자
#      - 학번: 그 외 자리수의 숫자 (보통 7자리)
#      - 이름: 영문 알파벳을 포함하는 단어
#    예시 모두 통과:
#      "00 Kim Programming 3741200"
#      "00 3741200 Kim Programming"
#      "Class: 00, Name: Kim, ID: 3741200"
# ─────────────────────────────────────────────────────────
FIRST_LINE=$(echo "$SMOKE_OUT" | head -n1)

check_student_info() {
    local line="$1"
    local two_digit=0 other_num=0 has_alpha=0
    # 영문 알파벳 존재 확인 (이름)
    echo "$line" | grep -Eq '[A-Za-z]' && has_alpha=1
    # 모든 순수 숫자 토큰 추출 (쉼표/콜론/공백으로 분리)
    for tok in $(echo "$line" | tr ',:;()' ' '); do
        if echo "$tok" | grep -Eq '^[0-9]+$'; then
            if [ "${#tok}" -eq 2 ]; then
                two_digit=$((two_digit+1))
            else
                other_num=$((other_num+1))
            fi
        fi
    done
    [ "$has_alpha" -eq 1 ] && [ "$two_digit" -ge 1 ] && [ "$other_num" -ge 1 ]
}

if check_student_info "$FIRST_LINE"; then
    pass 1 "2-0: 학생 정보(분반/이름/학번) 출력 OK"
else
    fail 1 "2-0: 학생 정보에 분반(2자리)/학번(숫자)/이름(영문) 중 일부 누락"
    info "받은 첫 줄: \"$FIRST_LINE\""
fi

# ─────────────────────────────────────────────────────────
# 3) 2-1: 배열 주소 N개를 4바이트씩 연속 출력 (2점)
#    N은 위에서 감지한 배열 크기
# ─────────────────────────────────────────────────────────
if [ "$SIZE_DETECTED" -eq 1 ]; then
    if [ "$N" -eq 1 ]; then
        # 배열 크기 1: 연속성 검사 불가, 주소 1개 출력만으로 만점
        pass 2 "2-1: 배열 ${N}개의 주소 출력됨 (크기 1이라 연속성 검사 생략)"
    else
        CONSECUTIVE=1
        for ((i=0; i<N-1; i++)); do
            a=${PROBE_ADDRS[$i]}; b=${PROBE_ADDRS[$((i+1))]}
            diff=$((b - a))
            if [ "$diff" != "4" ]; then CONSECUTIVE=0; break; fi
        done
        if [ "$CONSECUTIVE" -eq 1 ]; then
            pass 2 "2-1: 배열 ${N}개의 주소가 4바이트씩 연속 출력됨"
        else
            pass 1 "2-1: 주소 ${N}개는 출력되었으나 4바이트 연속이 아님 (부분점수)"
            info "주소들: ${PROBE_ADDRS[*]}"
        fi
    fi
else
    # 주소는 출력하지 않았지만 배열 원소(값)는 N개 출력한 것으로 추정 → 부분점수 1점
    if [ "$N" -ge 1 ]; then
        pass 1 "2-1: 주소가 아닌 값을 출력 (부분점수, 배열 크기 ${N} 감지됨)"
        info "&a[i]로 주소를 출력해야 만점 (현재는 값 또는 학점을 출력한 것으로 보임)"
    else
        fail 2 "2-1: 배열 원소의 주소가 출력되지 않음"
    fi
fi

# ─────────────────────────────────────────────────────────
# 4) 2-2: Max/Min/Avg 정확성 (각 1점, 총 3점)
#    N개 입력으로 동적으로 케이스 생성 — 어떤 배열 크기에도 대응
# ─────────────────────────────────────────────────────────
declare -a INPUTS=(
    "$(ascending_input "$N")"        # 오름차순: 10 20 30 ...
    "$(repeat_value 100 "$N")"        # 모두 100
    "$(random_input 1 "$N")"          # 무작위 1
    "$(random_input 2 "$N")"          # 무작위 2
    "$(random_input 3 "$N")"          # 무작위 3
)

MAX_OK=0; MIN_OK=0; AVG_OK=0
TOTAL_CASES=${#INPUTS[@]}
DETAILS=()

for inp in "${INPUTS[@]}"; do
    out=$(echo "$inp" | "$BIN" 2>/dev/null)
    expected=($(compute_expected "$inp"))
    e_max=${expected[0]}; e_min=${expected[1]}; e_avg=${expected[2]}

    g_max=$(extract_num "max(imum)?|highest|largest|biggest" "$out")
    g_min=$(extract_num "min(imum)?|lowest|smallest" "$out")
    g_avg=$(extract_num "avg|average|mean" "$out")

    [ "$g_max" = "$e_max" ] && MAX_OK=$((MAX_OK+1)) \
        || DETAILS+=("Max: 입력[$inp] 기대=$e_max 받음=\"$g_max\"")
    [ "$g_min" = "$e_min" ] && MIN_OK=$((MIN_OK+1)) \
        || DETAILS+=("Min: 입력[$inp] 기대=$e_min 받음=\"$g_min\"")
    if [ -n "$g_avg" ] && near "$g_avg" "$e_avg"; then
        AVG_OK=$((AVG_OK+1))
    else
        DETAILS+=("Avg: 입력[$inp] 기대=$e_avg 받음=\"$g_avg\"")
    fi
done

# 모든 케이스를 통과해야 만점
if [ "$MAX_OK" -eq "$TOTAL_CASES" ]; then
    pass 1 "2-2: Max 값 정확 (${MAX_OK}/${TOTAL_CASES} 케이스)"
else
    fail 1 "2-2: Max 값 오류 (${MAX_OK}/${TOTAL_CASES} 케이스 통과)"
fi
if [ "$MIN_OK" -eq "$TOTAL_CASES" ]; then
    pass 1 "2-2: Min 값 정확 (${MIN_OK}/${TOTAL_CASES} 케이스)"
else
    fail 1 "2-2: Min 값 오류 (${MIN_OK}/${TOTAL_CASES} 케이스 통과)"
fi
if [ "$AVG_OK" -eq "$TOTAL_CASES" ]; then
    pass 1 "2-2: Avg 값 정확 (${AVG_OK}/${TOTAL_CASES} 케이스)"
else
    fail 1 "2-2: Avg 값 오류 (${AVG_OK}/${TOTAL_CASES} 케이스 통과)"
fi

# 실패 상세 (최대 5개)
for ((k=0; k<${#DETAILS[@]} && k<5; k++)); do info "${DETAILS[$k]}"; done

# ─────────────────────────────────────────────────────────
# 5) 2-3: getGrade 함수 동작 검증 (3점)
#    각 등급의 경계값 모두 검증 — N개 입력으로 동적 생성
# ─────────────────────────────────────────────────────────
SCORES=(100 90 89 80 79 70 65 60 59 0)

GRADE_PASS=0
GRADE_TOTAL=${#SCORES[@]}
GRADE_FAILS=()

for score in "${SCORES[@]}"; do
    inp=$(grade_input "$score" "$N")
    expected=$(expected_grade "$score")
    out=$(echo "$inp" | "$BIN" 2>/dev/null)
    got=$(extract_grade "$out")
    if [ "$got" = "$expected" ]; then
        GRADE_PASS=$((GRADE_PASS + 1))
    else
        GRADE_FAILS+=("점수=$score → 기대 $expected, 받음 \"$got\"")
    fi
done

RATIO=$((GRADE_PASS * 100 / GRADE_TOTAL))
if   [ "$RATIO" -eq 100 ]; then
    pass 3 "2-3: getGrade 함수 ${GRADE_PASS}/${GRADE_TOTAL} 통과 (모든 경계값 정확)"
elif [ "$RATIO" -ge 80  ]; then
    pass 2 "2-3: getGrade 함수 ${GRADE_PASS}/${GRADE_TOTAL} 통과 (부분점수)"
elif [ "$RATIO" -ge 50  ]; then
    pass 1 "2-3: getGrade 함수 ${GRADE_PASS}/${GRADE_TOTAL} 통과 (부분점수)"
else
    fail 3 "2-3: getGrade 함수 ${GRADE_PASS}/${GRADE_TOTAL} 통과"
fi
for ((k=0; k<${#GRADE_FAILS[@]} && k<5; k++)); do info "${GRADE_FAILS[$k]}"; done

# ─────────────────────────────────────────────────────────
# 결과 출력 및 종료 코드 결정
# ─────────────────────────────────────────────────────────
# 항목별 검사 모드: ./scoring.sh check <항목>
#   - 해당 항목이 만점이면 종료코드 0, 부분점수/실패면 종료코드 1
#   - GitHub Classroom에서 항목별로 테스트를 만들어 부분점수 합산 가능
#
# 전체 채점 모드: ./scoring.sh
#   - 콘솔에 채점표를 출력하고 만점이면 종료코드 0, 아니면 1
#
# 항목별 점수 추적 (전체 채점에서 누적된 LOG를 분석)

# 각 항목의 획득 점수를 LOG에서 추출
get_item_score() {
    # $1: 항목 키워드 (예: "2-0", "2-1", "실행 성공")
    local key=$1
    local matched=$(printf '%s\n' "${LOG[@]}" | grep -F "$key" | head -n1)
    if [ -z "$matched" ]; then
        echo "0"
        return
    fi
    # [PASS +N] 패턴에서 N 추출
    local pts=$(echo "$matched" | grep -oE '\+[0-9]+' | head -n1 | tr -d '+')
    echo "${pts:-0}"
}

# 항목의 만점 여부 확인 (만점이면 0, 아니면 1 종료)
item_pass_or_fail() {
    # $1: 항목 키워드, $2: 그 항목의 최대 점수
    local got=$(get_item_score "$1")
    local max=$2
    print_result
    echo
    echo "─── 항목 검사: $1 ───"
    echo "획득: ${got} / ${max}"
    if [ "$got" -ge "$max" ]; then
        echo "결과: ✅ 통과 (만점)"
        exit 0
    else
        echo "결과: ❌ 실패 (부분점수 또는 미통과)"
        exit 1
    fi
}

# 인자 파싱: check 모드인지 확인
CHECK_MODE=""
if [ "$1" = "check" ] && [ -n "$2" ]; then
    CHECK_MODE="$2"
fi

case "$CHECK_MODE" in
    "run")
        # 실행 가능성만 검사 (1점)
        item_pass_or_fail "실행 성공" 1
        ;;
    "0-0")
        # 학생정보 (1점)
        item_pass_or_fail "2-0:" 1
        ;;
    "0-1")
        # 배열 주소 연속성 (2점) — 만점 시에만 통과
        item_pass_or_fail "2-1:" 2
        ;;
    "0-1-partial")
        # 2-1 부분점수: 1점 이상 받았으면 통과 (값이라도 출력했으면)
        got=$(get_item_score "2-1:")
        print_result
        echo
        echo "─── 항목 검사: 2-1 (배열 출력 시도) ───"
        echo "획득: ${got} / 1"
        if [ "$got" -ge 1 ]; then
            echo "결과: ✅ 통과"
            exit 0
        else
            echo "결과: ❌ 실패 (배열을 전혀 출력하지 않음)"
            exit 1
        fi
        ;;
    "0-1-full")
        # 2-1 만점 보너스: 정확히 주소를 출력했을 때만 통과
        got=$(get_item_score "2-1:")
        print_result
        echo
        echo "─── 항목 검사: 2-1 (주소 정확 출력) ───"
        echo "획득: ${got} / 2"
        if [ "$got" -ge 2 ]; then
            echo "결과: ✅ 통과 (주소 정확 출력)"
            exit 0
        else
            echo "결과: ❌ 실패 (&a[i]로 주소를 출력해야 함)"
            exit 1
        fi
        ;;
    "0-2")
        # Max/Min/Avg 합계 (3점) — 세 항목이 모두 PASS여야 만점
        max_pts=$(get_item_score "Max 값")
        min_pts=$(get_item_score "Min 값")
        avg_pts=$(get_item_score "Avg 값")
        sum=$((max_pts + min_pts + avg_pts))
        print_result
        echo
        echo "─── 항목 검사: 2-2 (Max/Min/Avg) ───"
        echo "획득: ${sum} / 3 (Max:${max_pts}, Min:${min_pts}, Avg:${avg_pts})"
        if [ "$sum" -ge 3 ]; then
            echo "결과: ✅ 통과 (만점)"
            exit 0
        else
            echo "결과: ❌ 실패"
            exit 1
        fi
        ;;
    "0-3")
        # getGrade 함수 (3점)
        item_pass_or_fail "2-3:" 3
        ;;
    "")
        # 인자 없음 → 전체 채점 모드
        print_result
        if [ "$TOTAL" -ge "$MAX" ]; then
            exit 0
        else
            echo "※ 만점(${MAX}점) 미달: ${TOTAL}점"
            exit 1
        fi
        ;;
    *)
        echo "알 수 없는 검사 모드: $CHECK_MODE"
        echo "사용법: ./scoring.sh [check {run|0-0|0-1|0-2|0-3}]"
        exit 2
        ;;
esac
