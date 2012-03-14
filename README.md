# Best Time

1. Time of week
2. Time of day

```ruby
now = Time.now
conversions = [
  now,
  now + 3600,
  now + 7200
]

bt = BestTime.new(conversions, :week)
puts bt.buckets
bt.graph
```
