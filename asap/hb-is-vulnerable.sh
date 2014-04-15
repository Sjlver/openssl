#!/bin/sh

if [ $# -lt 2 ]; then
    echo "Usage: hb-is-vulnerable.sh <openssl binary> <length>" >&2
    exit 1
fi

openssl=$1
length=$2

script_dir="$(dirname "$0")"

printf "Starting openssl server..."
cd "$(dirname "$openssl")"
"$openssl" s_server -www > /tmp/openssl.$$.out 2>&1 &
openssl_pid=$!
sleep 1
printf " at PID $openssl_pid\n"
cd -

vulnerable=no
if "$script_dir/hb-test.py" -p 4433 -l "$length" localhost; then
    vulnerable=yes
fi

asan_caught_error=no
if grep AddressSanitizer /tmp/openssl.$$.out >/dev/null && \
   grep tls1_process_heartbeat /tmp/openssl.$$.out >/dev/null; then
    asan_caught_error=yes
fi

kill $openssl_pid 2>/dev/null || echo "openssl process already died..."
sleep 1
echo; echo "Server output..."
cat /tmp/openssl.$$.out
rm /tmp/openssl.$$.out

echo
echo "Vulnerable: $vulnerable"
echo "AddressSanitizer caught error: $asan_caught_error"

[ "$vulnerable" = "yes" ] && exit 0
[ "$asan_caught_error" = "yes" ] && exit 1
exit 2
