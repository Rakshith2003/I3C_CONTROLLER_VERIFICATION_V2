class c_1_4;
    bit[47:0] cfg_pid = 48'h0;
    rand bit[2:0] txn_type; // rand_mode = ON 
    rand bit[47:0] pid; // rand_mode = ON 

    constraint pid_valid_c_this    // (constraint_mode = ON) (../../src/hvl_top/target/i3c_target_tx.sv:86)
    {
       (txn_type == 3'h1 /* i3c_target_tx::txn_type_e::DAA */) -> (pid != 48'h0);
    }
    constraint WITH_CONSTRAINT_this    // (constraint_mode = ON) (../../src/hvl_top/target/target_sequences/i3c_target_daa_seq.sv:30)
    {
       (txn_type == 3'h1 /* i3c_target_tx::txn_type_e::DAA */);
       (pid == cfg_pid);
    }
endclass

program p_1_4;
    c_1_4 obj;
    string randState;

    initial
        begin
            obj = new;
            randState = "1xz11010zzxx0000xzz0xxzzxzx0x00zzzzxzxzxzzzxzzxxxxzzzzxzzzzxzzzz";
            obj.set_randstate(randState);
            obj.randomize();
        end
endprogram
