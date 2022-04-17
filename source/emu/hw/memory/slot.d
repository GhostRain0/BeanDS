module emu.hw.memory.slot;

import emu;
import util;

__gshared Slot slot;
final class Slot {
    HwType access_rights;

    private this() {}

    static void reset() {
        slot = new Slot();
    }

    void write_EXMEMCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                // TODO (TOneverDO): implement access timings for gba slot
                break;
            
            case 1:
                access_rights = data[3] ? HwType.NDS7 : HwType.NDS9;
                break;
        }
    }

    Byte read_EXMEMCNT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0: 
                break;

            case 1: 
                result[3] = access_rights == HwType.NDS7;
        }

        return result;
    }

    Byte read_EXMEMSTAT(int target_byte) {
        return read_EXMEMCNT(target_byte);
    }
}