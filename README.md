# EXQuery - Elixir Query

Functionality to help querying data.

The main goal is to be able to expose a simple query API to external
clients without exposing potentially harmful functions. For instance
to let the user reduce result set in a HTTP API and do some common
calculations without downloading a dataset and doing all the work in
excel.

## Examples

```
iex(1)> collection = [
 %{"timestamp" => 1434847787, "sensor" => "temp", "value" => 23.4},
 %{"timestamp" => 1434847757, "sensor" => "temp", "value" => 22.9},
 %{"timestamp" => 1434847727, "sensor" => "temp", "value" => 22.3},
 %{"timestamp" => 1434847628, "sensor" => "temp", "value" => 22.0},
 %{"timestamp" => 1434847617, "sensor" => "temp", "value" => 21.9},
 %{"timestamp" => 1434847587, "sensor" => "temp", "value" => 21.8},
 %{"timestamp" => 1434847527, "sensor" => "temp", "value" => 21.9},
 %{"timestamp" => 1434847517, "sensor" => "temp", "value" => 22.0},
 %{"timestamp" => 1434847467, "sensor" => "temp", "value" => 21.9},
 %{"timestamp" => 1434847447, "sensor" => "temp", "value" => 22.2},
 %{"timestamp" => 1434847417, "sensor" => "temp", "value" => 22.1},
]

iex(2)> collection |> Enum.filter(ExQuery.Query.from_string("value > 22 and value < 23"))

[%{"sensor" => "temp", "timestamp" => 1434847757, "value" => 22.9},
 %{"sensor" => "temp", "timestamp" => 1434847727, "value" => 22.3},
 %{"sensor" => "temp", "timestamp" => 1434847447, "value" => 22.2},
 %{"sensor" => "temp", "timestamp" => 1434847417, "value" => 22.1}]
```

## Future plans

Depending on time and interest support for specifying these options
may be added in the future:
 - `sort by` keyword
 - `group by`
 - `select *` like functionality to pick only certain variables
 - some aggregation i.e `select avg(value) as value/avg, max(value) as max/value`
	 to get this data like %{.., "value/avg" => 22.3, "value/max" => 23.4}
	 coupled with a timeframing feature in group by you could then
	 aggregate average/min/max on a minut/hourly/daily basis.
