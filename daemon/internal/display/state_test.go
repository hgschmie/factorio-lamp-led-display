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
