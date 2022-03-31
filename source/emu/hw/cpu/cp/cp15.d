module emu.hw.cpu.cp.cp15;

import emu;

import util;

__gshared Cp15 cp15;
final class Cp15 {
    static void reset() {
        cp15 = new Cp15();
    }

    bool itcm_absent;
    int  itcm_physical_size;
    int  itcm_virtual_size;
    int  itcm_region_base;
    bool dtcm_absent;
    int  dtcm_physical_size;
    int  dtcm_virtual_size;
    int  dtcm_region_base;

    Word read(Word opcode, Word cn, Word cm) {
        log_coprocessor("Received a CP15 read: %x %x %x", opcode, cn, cm);

        Word return_value = 0;

        // think of a prettier way to decode this stuff
        if (cn == 9 && cm == 1 && opcode == 0) {
            return_value[1 .. 5] = dtcm_virtual_size;
            return_value[12..31] = dtcm_region_base;
        }

        if (cn == 9 && cm == 1 && opcode == 1) {
            return_value[1 .. 5] = itcm_virtual_size;
            return_value[12..31] = itcm_region_base;
        }

        if (cn == 0 && cm == 0 && opcode == 2) {
            return_value[2]      = itcm_absent;
            return_value[6..9]   = itcm_physical_size;
            return_value[14]     = dtcm_absent;
            return_value[18..21] = dtcm_physical_size;
        }

        if (cn == 1 && cm == 0 && opcode == 0) {
            return_value[16] = tcm.dtcm_enabled;
            return_value[17] = tcm.dtcm_load_mode;
            return_value[18] = tcm.itcm_enabled;  
            return_value[19] = tcm.itcm_load_mode;          
        }

        return return_value;
    }

    void write(Word opcode, Word cn, Word cm, Word data) {
        log_coprocessor("Received a CP15 write: %x %x %x %x", opcode, cn, cm, data);
        arm7.num_log += 10;

        // think of a prettier way to decode this stuff
        if (cn == 9 && cm == 1 && opcode == 0) {
            dtcm_virtual_size = data[1 .. 5];
            dtcm_region_base  = data[12..31];

            tcm.dtcm_virtual_size = 512 << dtcm_virtual_size;
            tcm.dtcm_region_base  = dtcm_region_base << 12;
            log_coprocessor("set dtcm stuffs to %x %x", tcm.dtcm_virtual_size, tcm.dtcm_region_base);
        }

        if (cn == 9 && cm == 1 && opcode == 1) {
            itcm_virtual_size = data[1 .. 5];
            itcm_region_base  = data[12..31];

            tcm.itcm_virtual_size = 512 << itcm_virtual_size;
            log_coprocessor("set itcm stuffs to %x %x", tcm.itcm_virtual_size, tcm.itcm_region_base);
        }

        if (cn == 1 && cm == 0 && opcode == 0) {
            tcm.dtcm_enabled   = data[16];
            tcm.dtcm_load_mode = data[17];
            tcm.itcm_enabled   = data[18]; 
            tcm.itcm_load_mode = data[19];           
        }

        if (cn == 7 && cm == 0 && opcode == 4 && data == 0) {
            arm9.halt();
        }
    }

    Word get_data_tcm_size() { return Word(512 << 0); }
    Word get_data_tcm_base() { return Word(0   << 12);  }
}