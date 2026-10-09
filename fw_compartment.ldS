SECTIONS
{
	. = 0x80000000;

	.text :
	{
		*(.entry)
		*(.text)
		*(.text.*)
	}
}
