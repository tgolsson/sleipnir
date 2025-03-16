package zip

import "core:time"

msdos_date_time_to_time :: proc(clock: u16le, date: u16le) -> time.Time {
	clock := u16(clock)
	date := u16(date)

	second := (clock & 0b11111) * 2
	minute := (clock >> 5) & 0b111111
	hour := (clock >> 11) & 0b11111

	day := date & 0b11111
	month := (date >> 5) & 0b1111
	year := 1980 + (date >> 9) & 0b1111111

	t, _ := time.components_to_time(year, month, day, hour, minute, second)
	return t
}

time_to_msdos_date_time :: proc(t: time.Time) -> (clock: u16le, date: u16le) {
	year, month, day := time.date(t)
	hour, minute, second := time.clock_from_time(t)

	{
		hbits: u16 = (u16(hour) & 0b11111) << 11
		mbits: u16 = (u16(minute) & 0b111111) << 5
		sbits: u16 = (u16(second / 2) & 0b11111)
		clock = u16le(hbits | mbits | sbits)
	}

	{
		ybits: u16 = ((u16(year) - 1980) & 0b1111111) << 9
		mbits: u16 = ((u16(month) - 1) & 0b1111) << 5
		dbits: u16 = u16(day) & 0b11111
		date = u16le(ybits | mbits | dbits)
	}

	return
}
