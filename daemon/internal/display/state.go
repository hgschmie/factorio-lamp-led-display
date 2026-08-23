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
	channels     map[int]Value
	lastSnapshot time.Time
}

type Value struct {
	Status string
	Direct *protocol.Direct
}

func NewState() *State { return &State{channels: map[int]Value{}, sequences: map[string]uint64{}} }

func (s *State) Apply(p protocol.Packet, now time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if p.Sequence <= s.sequences[p.SaveID] {
		return false
	}
	if p.SaveID != s.saveID {
		s.saveID, s.channels, s.lastSnapshot = p.SaveID, map[int]Value{}, time.Time{}
	}
	if p.Type == "snapshot" {
		s.channels = make(map[int]Value, len(p.Channels))
		s.lastSnapshot = now
	}
	for _, c := range p.Channels {
		if direct, ok := c.Direct(); ok {
			copy := direct
			s.channels[c.ID] = Value{Direct: &copy}
		} else {
			s.channels[c.ID] = Value{Status: protocol.Classify(c.Status)}
		}
	}
	s.sequences[p.SaveID] = p.Sequence
	return true
}

func (s *State) Snapshot(now time.Time, staleAfter time.Duration) (map[int]Value, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make(map[int]Value, len(s.channels))
	for k, v := range s.channels {
		out[k] = v
	}
	return out, s.lastSnapshot.IsZero() || now.Sub(s.lastSnapshot) > staleAfter
}
