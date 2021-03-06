module emu.hw.memory.mmio;

import std.format;

import emu;
import util;

public {
    import emu.hw.memory.mmio.mmio7;
    import emu.hw.memory.mmio.mmio9;
}

enum {
    READ,
    WRITE,
    READ_WRITE
}

struct MMIORegister {
    this(string component, string name, uint address, int size, int access_type) {
        this.component      = component;
        this.name           = name;
        this.address        = address;
        this.size           = size;
        this.readable       = access_type != WRITE;
        this.writeable      = access_type != READ;

        this.stride         = -1;
        this.cnt            = -1;
        this.all_at_once    = false;
        this.filter_enabled = false;
        this.implemented    = true;
    }

    MMIORegister repeat(int cnt, int stride) {
        this.cnt    = cnt;
        this.stride = stride;

        return this;
    } 

    MMIORegister dont_decompose_into_bytes() {
        this.all_at_once = true;
        return this;
    }

    MMIORegister filter(bool function(int i) new_f)() {
        this.filter_enabled = true;
        this.f = new_f;
        return this;
    }

    MMIORegister unimplemented() {
        this.implemented = false;
        this.all_at_once = true;
        return this;
    }
    
    string component;
    string name;
    Word   address;
    int    size;

    int    cnt;
    int    stride;

    bool   all_at_once;

    bool   readable;
    bool   writeable;

    bool   filter_enabled;
    bool function(int i) f;

    bool   implemented;
}

final class MMIO(MMIORegister[] mmio_registers) {
    string name;
    this(string name) {
        this.name = name;
    }

    // static foreach (MMIORegister mr; mmio_registers) {
    //     mixin("enum %s = %d;".format(mr.name, mr.address));
    // }

    T read(T)(Word address) {
        import std.format;

        // log_unimplemented("VERBOSE MMIO: %s Reading from %x (size = %d)", name, address, T.sizeof);
        T value = T(0);

        static foreach (MMIORegister mr; mmio_registers) {
            static if (mr.readable && mr.all_at_once) {
                if (address + T.sizeof > mr.address && address < mr.address + mr.size) {
                    static if (mr.implemented) {
                        mixin("value |= %s.read_%s!T(address %% %d) << (8 * (address - mr.address));".format(mr.component, mr.name, mr.size));
                        static if (is(T == Byte)) return value;
                    } else {
                        log_unimplemented("Unimplemented %s read: %s (size = %d)", name, mr.name, T.sizeof);
                        return T(0);
                    }
                }
            }
        }

        static if (is(T == Word)) {
            value[0 .. 7] = value[0 .. 7] | read_byte(address + 0);
            value[8 ..15] = value[8 ..15] | read_byte(address + 1); 
            value[16..23] = value[16..23] | read_byte(address + 2); 
            value[24..31] = value[24..31] | read_byte(address + 3);
            return value;  
        }

        static if (is(T == Half)) {
            value[0.. 7] = value[0.. 7] | read_byte(address + 0); 
            value[8..15] = value[8..15] | read_byte(address + 1);
            return value;
        }

        static if (is(T == Byte)) {
            return read_byte(address);
        }
    }

    private Byte read_byte(Word address) {
        import std.format;

        mmio_switch: switch (address) {
            static foreach (MMIORegister mr; mmio_registers) {
                static if (mr.readable) {
                    static if (mr.stride == -1) {
                        static foreach(int offset; 0..mr.size) {
                            static if (!mr.filter_enabled || mr.f(offset)) {
                                case mr.address + offset:
                                    static if (!mr.all_at_once) {
                                        mixin("return %s.read_%s(%d);".format(mr.component, mr.name, offset));
                                    } else {
                                        mixin("break mmio_switch;");
                                    }
                            }
                        }
                    } else {
                        static foreach(int stride_offset; 0..mr.cnt) {
                            static foreach(int offset; 0..mr.size) {
                                static if (!mr.filter_enabled || mr.f(offset)) {
                                    case mr.address + stride_offset * mr.stride + offset:
                                        static if (!mr.all_at_once) {
                                            mixin("return %s.read_%s(%d, %d);".format(mr.component, mr.name, offset, stride_offset));
                                        } else {
                                            mixin("break mmio_switch;");
                                        }
                                }
                            }
                        }
                    }
                }
            }

            default: log_unimplemented("Unimplemented %s read: [%x]", name, address);
        }

        return Byte(0);
    }

    void write(T)(Word address, T value) {
        // log_unimplemented("VERBOSE MMIO: %s Writing %x to %x (size = %d)",  name, value, address, T.sizeof);

        import std.format;
        static foreach (MMIORegister mr; mmio_registers) {
            static if (mr.writeable && mr.all_at_once) {
                if (address + T.sizeof > mr.address && address < mr.address + mr.size) {
                    static if (mr.implemented) {
                        mixin("%s.write_%s!T(cast(T) (value >> (8 * (address - mr.address))), address %% %d);".format(mr.component, mr.name, mr.size));
                    } else {
                        log_unimplemented("Unimplemented %s write: [%s] = %08x (size = %d)", name, mr.name, value, T.sizeof);
                        return;
                    }
                }
            }
        }

        static if (is(T == Word)) {
            write_byte(address + 0, cast(Byte) value[0 .. 7]);
            write_byte(address + 1, cast(Byte) value[8 ..15]);
            write_byte(address + 2, cast(Byte) value[16..23]);
            write_byte(address + 3, cast(Byte) value[24..31]);
        }

        static if (is(T == Half)) {
            write_byte(address + 0, cast(Byte) value[0 .. 7]);
            write_byte(address + 1, cast(Byte) value[8 ..15]);
        }

        static if (is(T == Byte)) {
            write_byte(address, value);
        }
    }

    private void write_byte(Word address, Byte value) {
        import std.format;

        mmio_switch: switch (address) {
            static foreach (MMIORegister mr; mmio_registers) {
                static if (mr.writeable) {
                    static if (mr.stride == -1) {
                        static foreach(int offset; 0..mr.size) {
                            static if (!mr.filter_enabled || mr.f(offset)) {
                                case mr.address + offset:
                                    static if (!mr.all_at_once) {
                                        mixin("%s.write_%s(%d, value); break mmio_switch;".format(mr.component, mr.name, offset));
                                    } else {
                                        mixin("break mmio_switch;");
                                    }
                            }
                        }
                    } else {
                        static foreach(int stride_offset; 0..mr.cnt) {
                            static foreach(int offset; 0..mr.size) {
                                static if (!mr.filter_enabled || mr.f(offset)) {
                                    case mr.address + stride_offset * mr.stride + offset:
                                        static if (!mr.all_at_once) {
                                            mixin("%s.write_%s(%d, value, %d); break mmio_switch;".format(mr.component, mr.name, offset, stride_offset));
                                        } else {
                                            mixin("break mmio_switch;");
                                        }
                                }
                            }
                        }
                    }
                }
            }

            default: log_unimplemented("Unimplemented %s write: [%x] = %x", name, address, value);
        }
    }
}