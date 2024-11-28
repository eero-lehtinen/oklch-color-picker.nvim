local M = {}

local colors = {
  ['slate-50'] = 0xF8FAFC,
  ['slate-100'] = 0xF1F5F9,
  ['slate-200'] = 0xE2E8F0,
  ['slate-300'] = 0xCBD5E1,
  ['slate-400'] = 0x94A3B8,
  ['slate-500'] = 0x64748B,
  ['slate-600'] = 0x475569,
  ['slate-700'] = 0x334155,
  ['slate-800'] = 0x1E293B,
  ['slate-900'] = 0x0F172A,
  ['slate-950'] = 0x020617,
  ['gray-50'] = 0xF9FAFB,
  ['gray-100'] = 0xF3F4F6,
  ['gray-200'] = 0xE5E7EB,
  ['gray-300'] = 0xD1D5DB,
  ['gray-400'] = 0x9CA3AF,
  ['gray-500'] = 0x6B7280,
  ['gray-600'] = 0x4B5563,
  ['gray-700'] = 0x374151,
  ['gray-800'] = 0x1F2937,
  ['gray-900'] = 0x111827,
  ['gray-950'] = 0x030712,
  ['zinc-50'] = 0xFAFAFA,
  ['zinc-100'] = 0xF4F4F5,
  ['zinc-200'] = 0xE4E4E7,
  ['zinc-300'] = 0xD4D4D8,
  ['zinc-400'] = 0xA1A1AA,
  ['zinc-500'] = 0x71717A,
  ['zinc-600'] = 0x52525B,
  ['zinc-700'] = 0x3F3F46,
  ['zinc-800'] = 0x27272A,
  ['zinc-900'] = 0x18181B,
  ['zinc-950'] = 0x09090B,
  ['neutral-50'] = 0xFAFAFA,
  ['neutral-100'] = 0xF5F5F5,
  ['neutral-200'] = 0xE5E5E5,
  ['neutral-300'] = 0xD4D4D4,
  ['neutral-400'] = 0xA3A3A3,
  ['neutral-500'] = 0x737373,
  ['neutral-600'] = 0x525252,
  ['neutral-700'] = 0x404040,
  ['neutral-800'] = 0x262626,
  ['neutral-900'] = 0x171717,
  ['neutral-950'] = 0x0A0A0A,
  ['stone-50'] = 0xFAFAF9,
  ['stone-100'] = 0xF5F5F4,
  ['stone-200'] = 0xE7E5E4,
  ['stone-300'] = 0xD6D3D1,
  ['stone-400'] = 0xA8A29E,
  ['stone-500'] = 0x78716C,
  ['stone-600'] = 0x57534E,
  ['stone-700'] = 0x44403C,
  ['stone-800'] = 0x292524,
  ['stone-900'] = 0x1C1917,
  ['stone-950'] = 0x0C0A09,
  ['red-50'] = 0xFEF2F2,
  ['red-100'] = 0xFEE2E2,
  ['red-200'] = 0xFECACA,
  ['red-300'] = 0xFCA5A5,
  ['red-400'] = 0xF87171,
  ['red-500'] = 0xEF4444,
  ['red-600'] = 0xDC2626,
  ['red-700'] = 0xB91C1C,
  ['red-800'] = 0x991B1B,
  ['red-900'] = 0x7F1D1D,
  ['red-950'] = 0x450A0A,
  ['orange-50'] = 0xFFF7ED,
  ['orange-100'] = 0xFFEDD5,
  ['orange-200'] = 0xFED7AA,
  ['orange-300'] = 0xFDBA74,
  ['orange-400'] = 0xFB923C,
  ['orange-500'] = 0xF97316,
  ['orange-600'] = 0xEA580C,
  ['orange-700'] = 0xC2410C,
  ['orange-800'] = 0x9A3412,
  ['orange-900'] = 0x7C2D12,
  ['orange-950'] = 0x431407,
  ['amber-50'] = 0xFFFBEB,
  ['amber-100'] = 0xFEF3C7,
  ['amber-200'] = 0xFDE68A,
  ['amber-300'] = 0xFCD34D,
  ['amber-400'] = 0xFBBF24,
  ['amber-500'] = 0xF59E0B,
  ['amber-600'] = 0xD97706,
  ['amber-700'] = 0xB45309,
  ['amber-800'] = 0x92400E,
  ['amber-900'] = 0x78350F,
  ['amber-950'] = 0x451A03,
  ['yellow-50'] = 0xFEFCE8,
  ['yellow-100'] = 0xFEF9C3,
  ['yellow-200'] = 0xFEF08A,
  ['yellow-300'] = 0xFDE047,
  ['yellow-400'] = 0xFACC15,
  ['yellow-500'] = 0xEAB308,
  ['yellow-600'] = 0xCA8A04,
  ['yellow-700'] = 0xA16207,
  ['yellow-800'] = 0x854D0E,
  ['yellow-900'] = 0x713F12,
  ['yellow-950'] = 0x422006,
  ['lime-50'] = 0xF7FEE7,
  ['lime-100'] = 0xECFCCB,
  ['lime-200'] = 0xD9F99D,
  ['lime-300'] = 0xBEF264,
  ['lime-400'] = 0xA3E635,
  ['lime-500'] = 0x84CC16,
  ['lime-600'] = 0x65A30D,
  ['lime-700'] = 0x4D7C0F,
  ['lime-800'] = 0x3F6212,
  ['lime-900'] = 0x365314,
  ['lime-950'] = 0x1A2E05,
  ['green-50'] = 0xF0FDF4,
  ['green-100'] = 0xDCFCE7,
  ['green-200'] = 0xBBF7D0,
  ['green-300'] = 0x86EFAC,
  ['green-400'] = 0x4ADE80,
  ['green-500'] = 0x22C55E,
  ['green-600'] = 0x16A34A,
  ['green-700'] = 0x15803D,
  ['green-800'] = 0x166534,
  ['green-900'] = 0x14532D,
  ['green-950'] = 0x052E16,
  ['emerald-50'] = 0xECFDF5,
  ['emerald-100'] = 0xD1FAE5,
  ['emerald-200'] = 0xA7F3D0,
  ['emerald-300'] = 0x6EE7B7,
  ['emerald-400'] = 0x34D399,
  ['emerald-500'] = 0x10B981,
  ['emerald-600'] = 0x059669,
  ['emerald-700'] = 0x047857,
  ['emerald-800'] = 0x065F46,
  ['emerald-900'] = 0x064E3B,
  ['emerald-950'] = 0x022C22,
  ['teal-50'] = 0xF0FDFA,
  ['teal-100'] = 0xCCFBF1,
  ['teal-200'] = 0x99F6E4,
  ['teal-300'] = 0x5EEAD4,
  ['teal-400'] = 0x2DD4BF,
  ['teal-500'] = 0x14B8A6,
  ['teal-600'] = 0x0D9488,
  ['teal-700'] = 0x0F766E,
  ['teal-800'] = 0x115E59,
  ['teal-900'] = 0x134E4A,
  ['teal-950'] = 0x042F2E,
  ['cyan-50'] = 0xECFEFF,
  ['cyan-100'] = 0xCFFAFE,
  ['cyan-200'] = 0xA5F3FC,
  ['cyan-300'] = 0x67E8F9,
  ['cyan-400'] = 0x22D3EE,
  ['cyan-500'] = 0x06B6D4,
  ['cyan-600'] = 0x0891B2,
  ['cyan-700'] = 0x0E7490,
  ['cyan-800'] = 0x155E75,
  ['cyan-900'] = 0x164E63,
  ['cyan-950'] = 0x083344,
  ['sky-50'] = 0xF0F9FF,
  ['sky-100'] = 0xE0F2FE,
  ['sky-200'] = 0xBAE6FD,
  ['sky-300'] = 0x7DD3FC,
  ['sky-400'] = 0x38BDF8,
  ['sky-500'] = 0x0EA5E9,
  ['sky-600'] = 0x0284C7,
  ['sky-700'] = 0x0369A1,
  ['sky-800'] = 0x075985,
  ['sky-900'] = 0x0C4A6E,
  ['sky-950'] = 0x082F49,
  ['blue-50'] = 0xEFF6FF,
  ['blue-100'] = 0xDBEAFE,
  ['blue-200'] = 0xBFDBFE,
  ['blue-300'] = 0x93C5FD,
  ['blue-400'] = 0x60A5FA,
  ['blue-500'] = 0x3B82F6,
  ['blue-600'] = 0x2563EB,
  ['blue-700'] = 0x1D4ED8,
  ['blue-800'] = 0x1E40AF,
  ['blue-900'] = 0x1E3A8A,
  ['blue-950'] = 0x172554,
  ['indigo-50'] = 0xEEF2FF,
  ['indigo-100'] = 0xE0E7FF,
  ['indigo-200'] = 0xC7D2FE,
  ['indigo-300'] = 0xA5B4FC,
  ['indigo-400'] = 0x818CF8,
  ['indigo-500'] = 0x6366F1,
  ['indigo-600'] = 0x4F46E5,
  ['indigo-700'] = 0x4338CA,
  ['indigo-800'] = 0x3730A3,
  ['indigo-900'] = 0x312E81,
  ['indigo-950'] = 0x1E1B4B,
  ['violet-50'] = 0xF5F3FF,
  ['violet-100'] = 0xEDE9FE,
  ['violet-200'] = 0xDDD6FE,
  ['violet-300'] = 0xC4B5FD,
  ['violet-400'] = 0xA78BFA,
  ['violet-500'] = 0x8B5CF6,
  ['violet-600'] = 0x7C3AED,
  ['violet-700'] = 0x6D28D9,
  ['violet-800'] = 0x5B21B6,
  ['violet-900'] = 0x4C1D95,
  ['violet-950'] = 0x2E1065,
  ['purple-50'] = 0xFAF5FF,
  ['purple-100'] = 0xF3E8FF,
  ['purple-200'] = 0xE9D5FF,
  ['purple-300'] = 0xD8B4FE,
  ['purple-400'] = 0xC084FC,
  ['purple-500'] = 0xA855F7,
  ['purple-600'] = 0x9333EA,
  ['purple-700'] = 0x7E22CE,
  ['purple-800'] = 0x6B21A8,
  ['purple-900'] = 0x581C87,
  ['purple-950'] = 0x3B0764,
  ['fuchsia-50'] = 0xFDF4FF,
  ['fuchsia-100'] = 0xFAE8FF,
  ['fuchsia-200'] = 0xF5D0FE,
  ['fuchsia-300'] = 0xF0ABFC,
  ['fuchsia-400'] = 0xE879F9,
  ['fuchsia-500'] = 0xD946EF,
  ['fuchsia-600'] = 0xC026D3,
  ['fuchsia-700'] = 0xA21CAF,
  ['fuchsia-800'] = 0x86198F,
  ['fuchsia-900'] = 0x701A75,
  ['fuchsia-950'] = 0x4A044E,
  ['pink-50'] = 0xFDF2F8,
  ['pink-100'] = 0xFCE7F3,
  ['pink-200'] = 0xFBCFE8,
  ['pink-300'] = 0xF9A8D4,
  ['pink-400'] = 0xF472B6,
  ['pink-500'] = 0xEC4899,
  ['pink-600'] = 0xDB2777,
  ['pink-700'] = 0xBE185D,
  ['pink-800'] = 0x9D174D,
  ['pink-900'] = 0x831843,
  ['pink-950'] = 0x500724,
  ['rose-50'] = 0xFFF1F2,
  ['rose-100'] = 0xFFE4E6,
  ['rose-200'] = 0xFECDD3,
  ['rose-300'] = 0xFDA4AF,
  ['rose-400'] = 0xFB7185,
  ['rose-500'] = 0xF43F5E,
  ['rose-600'] = 0xE11D48,
  ['rose-700'] = 0xBE123C,
  ['rose-800'] = 0x9F1239,
  ['rose-900'] = 0x881337,
  ['rose-950'] = 0x4C0519,
}

--- Returns color of tailwind string, e.g. slate-700
---@param match string
---@return integer
function M.custom_parse(match)
  print(match)
  return colors[match]
end

return M
