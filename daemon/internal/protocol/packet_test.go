package protocol

import "testing"

func TestDecode(t *testing.T) {
	p, err := Decode([]byte(`{"version":1,"save_id":"save","sequence":2,"tick":30,"type":"snapshot","channels":[{"id":"a","status":"working"}]}`))
	if err != nil || p.SaveID != "save" || len(p.Channels) != 1 {
		t.Fatalf("Decode() = %#v, %v", p, err)
	}
	for _, bad := range []string{
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[]}`,
		`{"version":1,"save_id":"","sequence":1,"type":"snapshot","channels":[]}`,
		`{"version":1,"save_id":"s","sequence":1,"type":"bogus","channels":[]}`,
		`{"version":1,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":"a","status":"working"},{"id":"a","status":"working"}]}`,
		`{"version":1,"save_id":"s","sequence":1,"type":"snapshot","channels":[]} {}`,
	} {
		if _, err := Decode([]byte(bad)); err == nil {
			t.Errorf("Decode(%s) unexpectedly succeeded", bad)
		}
	}
}

func TestClassify(t *testing.T) {
	tests := map[string]string{
		"working": "working", "no-ingredients": "starved", "full-output": "blocked",
		"no-power": "no_power", "disabled-by-script": "disabled", "missing": "missing", "weird": "unknown",
	}
	for in, want := range tests {
		if got := Classify(in); got != want {
			t.Errorf("Classify(%q)=%q, want %q", in, got, want)
		}
	}
}
