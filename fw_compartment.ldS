SECTIONS
{
	. = 0x80000000;

	.text :
	{
		*(.entry)
		*(.text)
		*(.text.*)
	}

	/* Keep data next to the code, ahead of the compartment, so the host's
	 * PC-relative references reach it however large the compartment is. */
	.data : { *(.data) *(.data.*) }

	/* The compartment last, after everything the host addresses. */
	.compartment_bits : { *(.compartment_bits) }
}
