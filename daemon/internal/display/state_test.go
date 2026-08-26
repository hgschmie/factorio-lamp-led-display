package display

import (
	"github.com/example/factorio-physical-display/daemon/internal/protocol"
	"testing"
	"time"
)

func TestStateSequenceAndStale(t *testing.T) {
	s := NewState()
	now := time.Unix(100, 0)
	p := protocol.Packet{SaveID: "s", Sequence: 2, Type: "snapshot", Channels: []protocol.Channel{{ID: 0, Status: "working"}}}
	if !s.Apply(p, now) {
		t.Fatal("initial rejected")
	}
	p.Sequence = 1
	if s.Apply(p, now) {
		t.Fatal("out of order accepted")
	}
	got, stale := s.Snapshot(now.Add(9*time.Second), 10*time.Second)
	if stale || got[0].Status != "working" {
		t.Fatalf("got %v stale=%v", got, stale)
	}
	_, stale = s.Snapshot(now.Add(11*time.Second), 10*time.Second)
	if !stale {
		t.Fatal("not stale")
	}
	up := protocol.Packet{SaveID: "s", Sequence: 3, Type: "update", Channels: []protocol.Channel{{ID: 0, Status: "no-power"}}}
	s.Apply(up, now.Add(11*time.Second))
	_, stale = s.Snapshot(now.Add(11*time.Second), 10*time.Second)
	if !stale {
		t.Fatal("update incorrectly refreshed snapshot timer")
	}
	newSave := protocol.Packet{SaveID: "new", Sequence: 1, Type: "snapshot", Channels: []protocol.Channel{}}
	if !s.Apply(newSave, now) {
		t.Fatal("new save sequence rejected")
	}
	if s.Apply(protocol.Packet{SaveID: "s", Sequence: 2, Type: "snapshot"}, now) {
		t.Fatal("late packet from earlier save accepted")
	}
	if !s.Apply(protocol.Packet{SaveID: "s", Sequence: 4, Type: "snapshot"}, now) {
		t.Fatal("newer sequence from reloaded save rejected")
	}
	r, g, b, brightness := uint8(8), uint8(9), uint8(10), uint8(11)
	directPacket := protocol.Packet{SaveID: "s", Sequence: 5, Type: "update", Channels: []protocol.Channel{{ID: 63, R: &r, G: &g, B: &b, Brightness: &brightness, Effect: "solid"}}}
	if !s.Apply(directPacket, now) {
		t.Fatal("direct packet rejected")
	}
	got, _ = s.Snapshot(now, 10*time.Second)
	if got[63].Direct == nil || got[63].Direct.Brightness != 11 {
		t.Fatalf("bad direct state %#v", got[63])
	}
}

func TestResetReplacesStateAndSequenceBaseline(t *testing.T) {
	s := NewState()
	now := time.Unix(200, 0)
	if !s.Apply(protocol.Packet{
		SaveID: "save", Sequence: 66, Type: "snapshot",
		Channels: []protocol.Channel{{ID: 0, Status: "working"}},
	}, now) {
		t.Fatal("initial snapshot rejected")
	}

	resetAt := now.Add(20 * time.Second)
	if !s.Apply(protocol.Packet{
		SaveID: "save", Sequence: 1, Type: "reset",
		Channels: []protocol.Channel{{ID: 7, Status: "no-power"}},
	}, resetAt) {
		t.Fatal("lower-sequence reset rejected")
	}
	got, stale := s.Snapshot(resetAt, 10*time.Second)
	if stale || len(got) != 1 || got[7].Status != "no_power" {
		t.Fatalf("reset did not replace state: got=%v stale=%v", got, stale)
	}
	if _, exists := got[0]; exists {
		t.Fatal("reset retained a channel from the previous snapshot")
	}

	if s.Apply(protocol.Packet{SaveID: "save", Sequence: 1, Type: "update", Channels: []protocol.Channel{{ID: 7, Status: "working"}}}, resetAt) {
		t.Fatal("packet equal to reset sequence was accepted")
	}
	if !s.Apply(protocol.Packet{SaveID: "save", Sequence: 2, Type: "update", Channels: []protocol.Channel{{ID: 7, Status: "working"}}}, resetAt) {
		t.Fatal("packet above reset sequence was rejected")
	}
	got, _ = s.Snapshot(resetAt, 10*time.Second)
	if got[7].Status != "working" {
		t.Fatalf("post-reset update not applied: %#v", got[7])
	}
}

func TestResetChangesSaveAndSupportsEmptyChannels(t *testing.T) {
	s := NewState()
	now := time.Unix(300, 0)
	if !s.Apply(protocol.Packet{SaveID: "old", Sequence: 10, Type: "snapshot", Channels: []protocol.Channel{{ID: 1, Status: "working"}}}, now) {
		t.Fatal("initial snapshot rejected")
	}
	resetAt := now.Add(20 * time.Second)
	if !s.Apply(protocol.Packet{SaveID: "new", Sequence: 1, Type: "reset", Channels: []protocol.Channel{}}, resetAt) {
		t.Fatal("empty reset rejected")
	}
	got, stale := s.Snapshot(resetAt.Add(9*time.Second), 10*time.Second)
	if stale || len(got) != 0 {
		t.Fatalf("empty reset state incorrect: got=%v stale=%v", got, stale)
	}
	_, stale = s.Snapshot(resetAt.Add(11*time.Second), 10*time.Second)
	if !stale {
		t.Fatal("reset did not establish a new snapshot timestamp")
	}
}
