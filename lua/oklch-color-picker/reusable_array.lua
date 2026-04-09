--- A table that tracks its own length in `.n`.
--- Call `clear` to reset the length to 0 but keep the table to to reduce allocations.
--- Call `seal` after all pushes to nil the sentinel so `ipairs` works.
---@class ReusableArray: { n: integer, [integer]: any }

local M = {}

---@return ReusableArray
function M.new()
  return { n = 0 }
end

---@param arr ReusableArray
---@param val any
function M.push(arr, val)
  local n = arr.n + 1
  arr.n = n
  arr[n] = val
end

---@param arr ReusableArray
function M.clear(arr)
  arr.n = 0
end

--- Nil out arr[n+1] so ipairs stops at the right place.
---@param arr ReusableArray
function M.seal(arr)
  arr[arr.n + 1] = nil
end

return M
