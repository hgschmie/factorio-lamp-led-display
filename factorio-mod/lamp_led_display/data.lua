------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

This, Framework = require('lib.init')()

require('prototypes.selection-tool')
require('prototypes.shortcut')
require('prototypes.custom-input')

local styles = data.raw['gui-style'].default

styles['led-table'] = {
    type = 'table_style',
    parent = 'table',
    margin = 4,
    cell_padding = 2,
    column_alignments = {
        { column = 1, alignment = 'middle-left' },
        { column = 2, alignment = 'middle-center' },
        { column = 3, alignment = 'middle-center' },
        { column = 4, alignment = 'middle-center' },
        { column = 5, alignment = 'middle-left' },
    },
} --[[@as TableStyleSpecification]]

---@diagnostic disable-next-line: undefined-field
Framework.post_data_stage()
