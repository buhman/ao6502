        ;; uint8_t * input_len = 8000;
        ;; uint16_t * input = 8001;
        ;; uint16_t ** input_j = 2;
        ;; uint16_t ** input_k = 4;
        ;; uint8_t * k_index = 0;
                LDA # 01    ;;
                STA zp 4    ;;
                LDA # 80    ;;
                STA zp 5    ;; *input_k = input
                LDA a 8000  ;;
                STA zp 0    ;; *k_index = *input_len

_loopx:         LDA # 01    ;;
                STA zp 2    ;;
                LDA # 80    ;;
                STA zp 3    ;; *input_j = input
                LDA a 8000  ;;
                TAX i       ;; X = *input_len

_loop:          CLC i         ;; /* 16-bit addition+comparison (lower byte) */
                LDY # 0       ;;
                LDA (zp),y 2  ;;
                ADC (zp),y 4  ;; A = ((uint8_t *)(*input_j))[0] + ((uint8_t *)(*input_k))[0]
                PHP s         ;;
                CMP # E4      ;;
                BNE r :_next  ;; if (A != 0xE4) goto _next

                PLP s         ;; /* 16-bit addition+comparison (upper byte) */
                LDY # 1       ;;
                LDA (zp),y 2  ;;
                ADC (zp),y 4  ;; A = ((uint8_t *)(*input_j))[1] + ((uint8_t *)(*input_k))[1]
                CMP # 07      ;;
                BEQ r :_found ;; if (A == 0x07) goto _found

_next:          CLC i         ;;
                LDA zp 2      ;;
                ADC # 2       ;;
                STA zp 2      ;;
                LDA zp 3      ;;
                ADC # 0       ;;
                STA zp 3      ;; *input_j = *input_j + 2
                DEX i         ;;
                BNE r :_loop  ;; if (--X != 0) goto _loop

                CLC i         ;;
                LDA zp 4      ;;
                ADC # 2       ;;
                STA zp 4      ;;
                LDA zp 5      ;;
                ADC # 0       ;;
                STA zp 5      ;; *input_k = *input_k + 2
                LDY zp 0      ;;
                DEY i         ;;
                STY zp 0      ;; *k_index = k_index - 1;
                BNE r :_loopx ;; if (*k_index != 0) goto _loopx

_not_found:     JMP a :_not_found

_found:         LDY # 0       ;; copy **input_j and **input_k to mul24 `a` and `b` arguments
                LDA (zp),y 2  ;;
                STA zp 8      ;;
                LDA (zp),y 4  ;;
                STA zp B      ;;
                              ;;
                LDY # 1       ;;
                LDA (zp),y 2  ;;
                STA zp 9      ;;
                LDA (zp),y 4  ;;
                STA zp C      ;;
                              ;;
                LDA # 0       ;;
                STA zp A      ;;
                STA zp D      ;;

;; multiply two 24-bit operands; 24-bit product
;;
;; r = a * b

        ;; uint24_t * a = [8, 9, a]
        ;; uint24_t * b = [b, c, d]
        ;; uint24_t * r = [10, 11, 12]
mul24:          LDA # 0
                STA zp 10
                STA zp 11
                STA zp 12

_mul24_loop:    LDA zp 8          ;; while (a) {
                ORA zp 9          ;;
                ORA zp A          ;;
                BEQ r :_mul24_ret ;;

                LDA # 1              ;; if (a & 1)
                AND zp 8             ;;
                BEQ r :_mul24_nand_1 ;;

                CLC i            ;; r += b;
                LDA zp B         ;;; 7..0
                ADC zp 10         ;;
                STA zp 10         ;;
                LDA zp C         ;;; 15..8
                ADC zp 11         ;;
                STA zp 11         ;;
                LDA zp D         ;;; 23..16
                ADC zp 12         ;;
                STA zp 12         ;;

_mul24_nand_1:  LSR zp A         ;; a >>= 1
                ROR zp 9         ;;
                ROR zp 8         ;;

                ASL zp B         ;; b <<= 1
                ROL zp C         ;;
                ROL zp D         ;;

                JMP a :_mul24_loop ;; }

_mul24_ret:     JMP a :_mul24_ret  ;; return r
