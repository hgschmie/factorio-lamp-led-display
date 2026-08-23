package protocol

import "testing"

func TestDecode(t *testing.T) {
	p, err := Decode([]byte(`{"version":2,"save_id":"save","sequence":2,"tick":30,"type":"snapshot","channels":[{"id":0,"status":"working"}]}`))
	if err != nil || p.SaveID != "save" || len(p.Channels) != 1 {
		t.Fatalf("Decode() = %#v, %v", p, err)
	}
	direct, err := Decode([]byte(`{"version":2,"save_id":"save","sequence":3,"tick":31,"type":"update","channels":[{"id":63,"r":1,"g":2,"b":3,"brightness":127,"effect":"pulse"}]}`))
	if err != nil {
		t.Fatal(err)
	}
	color, ok := direct.Channels[0].Direct()
	if !ok || color.G != 2 || color.Brightness != 127 || color.Effect != "pulse" {
		t.Fatalf("bad direct channel %#v", direct.Channels[0])
	}
	empty, err := Decode([]byte(`{"version":2,"save_id":"save","sequence":4,"tick":32,"type":"snapshot","channels":{}}`))
	if err != nil || len(empty.Channels) != 0 {
		t.Fatalf("Factorio-style empty channels object rejected: %#v, %v", empty, err)
	}
	for _, bad := range []string{
		`{"version":1,"save_id":"s","sequence":1,"type":"snapshot","channels":[]}`,
		`{"version":2,"save_id":"","sequence":1,"type":"snapshot","channels":[]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"bogus","channels":[]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":1,"status":"working"},{"id":1,"status":"working"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":"named","status":"working"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":-1,"status":"working"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":64,"status":"working"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"status":"working"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[]} {}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":2,"r":1,"g":2,"effect":"solid"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":[{"id":2,"r":1,"g":2,"b":3,"brightness":4,"effect":"sparkle"}]}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot","channels":{"id":1}}`,
		`{"version":2,"save_id":"s","sequence":1,"type":"snapshot"}`,
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
