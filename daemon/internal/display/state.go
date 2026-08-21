package display

import (
	"sync"
	"time"

	"github.com/example/factorio-physical-display/daemon/internal/protocol"
)

type State struct {
	mu           sync.RWMutex
	saveID       string
	sequences    map[string]uint64
	channels     map[string]string
	lastSnapshot time.Time
}

func NewState() *State { return &State{channels: map[string]string{}, sequences: map[string]uint64{}} }

func (s *State) Apply(p protocol.Packet, now time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if p.Sequence <= s.sequences[p.SaveID] {
		return false
	}
	if p.SaveID != s.saveID {
		s.saveID, s.channels, s.lastSnapshot = p.SaveID, map[string]string{}, time.Time{}
	}
	if p.Type == "snapshot" {
		s.channels = make(map[string]string, len(p.Channels))
		s.lastSnapshot = now
	}
	for _, c := range p.Channels {
		s.channels[c.ID] = protocol.Classify(c.Status)
	}
	s.sequences[p.SaveID] = p.Sequence
	return true
}

func (s *State) Snapshot(now time.Time, staleAfter time.Duration) (map[string]string, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make(map[string]string, len(s.channels))
	for k, v := range s.channels {
		out[k] = v
	}
	return out, s.lastSnapshot.IsZero() || now.Sub(s.lastSnapshot) > staleAfter
}
