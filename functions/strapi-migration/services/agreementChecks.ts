import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';

/**
 * Splits an array into batches of the specified size
 * @param array
 * @param batchSize
 * @returns T[][]
 */
function splitIntoBatches<T>(array: T[], batchSize: number): T[][] {
	const batches: T[][] = [];
	for (let i = 0; i < array.length; i += batchSize) {
		batches.push(array.slice(i, i + batchSize));
	}
	return batches;
}

interface ExistingAgreement {
	email: string;
	document_number: string;
}

/**
 * Checks for existing agreements in Supabase by email in batches
 * @param supabaseClient
 * @param emails
 * @param batchSize
 * @returns Promise<ExistingAgreement[]>
 */
async function checkExistingAgreementsByEmail(
	supabaseClient: SupabaseClient,
	emails: string[],
	batchSize: number = 50,
): Promise<ExistingAgreement[]> {
	const existingAgreements: ExistingAgreement[] = [];
	const emailBatches = splitIntoBatches(emails, batchSize);

	console.log(
		`Processing ${emails.length} emails in ${emailBatches.length} batches`,
	);

	for (let i = 0; i < emailBatches.length; i++) {
		const batch = emailBatches[i];
		console.log(
			`Processing email batch ${
				i + 1
			}/${emailBatches.length} (${batch.length} emails)`,
		);

		try {
			const { data, error } = await supabaseClient
				.from('agreements')
				.select('email, document_number')
				.in('email', batch);

			if (error) {
				console.error(
					`Error checking for existing emails in batch ${i + 1}:`,
					error,
				);
				throw error;
			}

			if (data && data.length > 0) {
				existingAgreements.push(...data);
			}
		} catch (error) {
			console.error(`Error processing email batch ${i + 1}:`, error);
			throw error;
		}
	}

	return existingAgreements;
}

/**
 * @param supabaseClient
 * @param documentNumbers
 * @param existingAgreements
 * @param batchSize
 * @returns Promise<ExistingAgreement[]>
 */
async function checkExistingAgreementsByDocumentNumber(
	supabaseClient: SupabaseClient,
	documentNumbers: string[],
	existingAgreements: ExistingAgreement[],
	batchSize: number = 50,
): Promise<ExistingAgreement[]> {
	const remainingDocumentNumbers = documentNumbers.filter((doc) =>
		!existingAgreements.some((existing) =>
			existing.document_number.toLowerCase() === doc.toLowerCase()
		)
	);

	if (remainingDocumentNumbers.length === 0) {
		return [];
	}

	const newExistingAgreements: ExistingAgreement[] = [];
	const docBatches = splitIntoBatches(remainingDocumentNumbers, batchSize);

	console.log(
		`Processing ${remainingDocumentNumbers.length} document numbers in ${docBatches.length} batches`,
	);

	for (let i = 0; i < docBatches.length; i++) {
		const batch = docBatches[i];
		console.log(
			`Processing document number batch ${
				i + 1
			}/${docBatches.length} (${batch.length} document numbers)`,
		);

		try {
			const { data, error } = await supabaseClient
				.from('agreements')
				.select('email, document_number')
				.in('document_number', batch);

			if (error) {
				console.error(
					`Error checking for existing document numbers in batch ${
						i + 1
					}:`,
					error,
				);
				throw error;
			}

			if (data && data.length > 0) {
				// Filter out duplicates
				data.forEach((docResult) => {
					if (
						!existingAgreements.some((existing) =>
							existing.email.toLowerCase() ===
								docResult.email.toLowerCase() &&
							existing.document_number.toLowerCase() ===
								docResult.document_number.toLowerCase()
						)
					) {
						newExistingAgreements.push(docResult);
					}
				});
			}
		} catch (error) {
			console.error(
				`Error processing document number batch ${i + 1}:`,
				error,
			);
			throw error;
		}
	}

	return newExistingAgreements;
}

/**
 * @param supabaseClient
 * @param emails
 * @param documentNumbers
 * @param batchSize
 * @returns Promise<ExistingAgreement[]>
 */
export async function checkExistingAgreementsInBatches(
	supabaseClient: SupabaseClient,
	emails: string[],
	documentNumbers: string[],
	batchSize: number = 50,
): Promise<ExistingAgreement[]> {
	if (emails.length === 0 || documentNumbers.length === 0) {
		return [];
	}

	/* Check for existing agreement in batches */
	const existingAgreementsByEmail = await checkExistingAgreementsByEmail(
		supabaseClient,
		emails,
		batchSize,
	);

	const existingAgreementsByDocNumber =
		await checkExistingAgreementsByDocumentNumber(
			supabaseClient,
			documentNumbers,
			existingAgreementsByEmail,
			batchSize,
		);

	// Combine results, avoiding duplicates
	const allExistingAgreements = [...existingAgreementsByEmail];

	existingAgreementsByDocNumber.forEach((docAgreement) => {
		if (
			!allExistingAgreements.some((existing) =>
				existing.email.toLowerCase() ===
					docAgreement.email.toLowerCase() &&
				existing.document_number.toLowerCase() ===
					docAgreement.document_number.toLowerCase()
			)
		) {
			allExistingAgreements.push(docAgreement);
		}
	});

	console.log(
		`Found ${allExistingAgreements.length} total existing agreements`,
	);
	return allExistingAgreements;
}
